import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sip_ua/sip_ua.dart';

import 'src/access/access_preferences.dart';
import 'src/access/access_screen.dart';
import 'src/account/webrtc_account.dart';
import 'src/audio/keypad_tone_player.dart';
import 'src/bridge/phone_bridge.dart';
import 'src/bridge/phone_bridge_transport.dart';
import 'src/bridge/voip_bridge_host.dart';
import 'src/brand/brand.dart';
import 'src/contacts/native_contacts_repository.dart';
import 'src/contacts/phone_contact.dart';
import 'src/i18n/phoneweb_strings.dart';
import 'src/session/mnscloud_session_api.dart';
import 'src/session/mnscloud_session_controller.dart';
import 'src/session/mnscloud_session_section.dart';
import 'src/storage/standalone_phoneweb_store.dart';
import 'src/version/app_update_controller.dart';
import 'src/version/app_update_notice.dart';
import 'src/version/runtime_version.dart';
import 'src/voip/phoneweb_voip_controller.dart';
import 'src/pwa/install_app_button.dart';

void main() {
  // A new language (access screen or Settings) redraws every screen at once.
  accessLocale.addListener(_rebuildAllScreens);
  runApp(const PhoneWebApp());
  // Web only: the domain brand (Settings › Themes › PhoneWeb) and the access language.
  if (kIsWeb) {
    unawaited(loadPhoneWebBrand());
    unawaited(loadAccessLocale());
  }
}

void _rebuildAllScreens() {
  void rebuild(Element element) {
    element.markNeedsBuild();
    element.visitChildren(rebuild);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
}

class PhoneWebApp extends StatelessWidget {
  const PhoneWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brand?>(
      valueListenable: phonewebBrand,
      builder: (context, brand, _) => MaterialApp(
        title: brand?.title ?? 'MNSCloud PhoneWeb',
        debugShowCheckedModeBanner: false,
        theme: _phoneWebTheme(Brightness.light),
        darkTheme: _phoneWebTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        scrollBehavior: const PhoneWebScrollBehavior(),
        home: const PhoneWebHomePage(),
      ),
    );
  }
}

class PhoneWebScrollBehavior extends MaterialScrollBehavior {
  const PhoneWebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

ThemeData _phoneWebTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF151515)
        : const Color(0xFFF7F8F5),
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: dark ? const Color(0xFF252525) : Colors.white,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1F1F1F) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
  );
}

class PhoneWebHomePage extends StatefulWidget {
  const PhoneWebHomePage({super.key});

  @override
  State<PhoneWebHomePage> createState() => _PhoneWebHomePageState();
}

class _PhoneWebHomePageState extends State<PhoneWebHomePage> {
  final List<WebRtcAccount> _accounts = [];
  final List<PhoneContact> _contacts = [];
  final List<PhoneCallHistoryEntry> _callHistory = [];
  final StandalonePhoneWebStore _store = StandalonePhoneWebStore();
  final NativeContactsRepository _contactsRepository =
      NativeContactsRepository();
  final KeypadTonePlayer _keypadTonePlayer = KeypadTonePlayer();
  late final PhoneWebVoipController _voip;
  final MnscloudSessionController _mnscloud = MnscloudSessionController();
  String? _selectedAccountId;
  String _dialNumber = '';
  String _lastEvent = tr('Ready');
  int _mobileTabIndex = 0;
  bool _contactsSyncing = false;
  final AppUpdateController _update = AppUpdateController();
  bool _standaloneDirty = false;
  bool _hadActiveCall = false;
  bool _trackedCallEstablished = false;
  bool _trackedCallIncoming = false;
  String _trackedCallRemote = '';
  String _trackedCallAccountName = '';
  String _trackedCallDiagnostic = '';
  DateTime? _trackedCallStartedAt;
  Timer? _iceRefreshTimer;
  PhoneBridge? _bridge;

  /// The web shows the access screen until the user signs in or continues
  /// without an account; never inside the App dock (`?embed=app`).
  final bool _accessGate = kIsWeb && Uri.base.queryParameters['embed'] != 'app';
  bool _accessReady = false;
  bool _accessSkipped = false;

  @override
  void initState() {
    super.initState();
    _voip = PhoneWebVoipController();
    _voip.addListener(_syncVoipState);
    _loadStandaloneState();
    _update.addListener(_onUpdateChanged);
    _update.start();
    _mnscloud.addListener(_onMnscloudChanged);
    unawaited(_restoreSession());
    // Embedded in the App phone dock (`?embed=app`): Phone Bridge v1.
    final bridgeTransport = createEmbeddedBridgeTransport();
    if (bridgeTransport != null) {
      _bridge = PhoneBridge(
        host: VoipBridgeHost(_voip, _mnscloud),
        transport: bridgeTransport,
        appVersion: currentRuntimeVersionInfo().version,
        onFocus: _focusFromBridge,
      )..start();
    }
    _iceRefreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => unawaited(_refreshManagedIce()),
    );
  }

  @override
  void dispose() {
    _iceRefreshTimer?.cancel();
    _bridge?.dispose();
    _voip.removeListener(_syncVoipState);
    _voip.dispose();
    _update.removeListener(_onUpdateChanged);
    _update.dispose();
    _mnscloud.removeListener(_onMnscloudChanged);
    _mnscloud.dispose();
    _keypadTonePlayer.dispose();
    super.dispose();
  }

  WebRtcAccount? get _selectedAccount {
    for (final account in _accounts) {
      if (account.id == _selectedAccountId) {
        return account;
      }
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  RuntimeVersionInfo get _runtimeVersion => _update.versionInfo;

  Future<void> _refreshRuntimeVersion() => _update.check(force: true);

  void _onUpdateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStandaloneState() async {
    final state = await _store.load();
    if (!mounted) return;
    if (_standaloneDirty) {
      return;
    }
    setState(() {
      _accounts
        ..clear()
        ..addAll(state.accounts.where((account) => account.id.isNotEmpty));
      _contacts
        ..clear()
        ..addAll(state.contacts.where((contact) => contact.id.isNotEmpty));
      _callHistory
        ..clear()
        ..addAll(
          state.callHistory.where((entry) => entry.id.isNotEmpty).take(250),
        );
      _selectedAccountId =
          state.selectedAccountId != null &&
              _accounts.any((account) => account.id == state.selectedAccountId)
          ? state.selectedAccountId
          : (_accounts.isEmpty ? null : _accounts.first.id);
    });

    final selectedAccountId = _selectedAccountId;
    if (selectedAccountId != null &&
        _accounts.where((account) => account.enabled).length > 1) {
      setState(() => _enforceSingleActiveAccount(selectedAccountId));
      await _saveStandaloneAccounts();
    }

    final account = _selectedAccount;
    if (account != null && account.enabled && account.autoRegister) {
      await _voip.register(account);
    }
  }

  Future<void> _saveStandaloneAccounts() {
    _standaloneDirty = true;
    final selected = _selectedAccountId;
    return _store.saveAccounts(
      _accounts.where((account) => !account.managed).toList(),
      selectedAccountId: selected != null && selected.startsWith(_managedPrefix)
          ? null
          : selected,
    );
  }

  static const _managedPrefix = 'mnscloud:';
  bool _syncingLines = false;
  bool _syncAgain = false;

  /// Resumes the MNSCloud session (or the App handoff) before deciding whether
  /// the access screen is needed, so a signed-in user never sees it flash.
  Future<void> _restoreSession() async {
    final skipped = _accessGate ? await readAccessSkipped() : true;
    await _mnscloud.restore();
    if (!mounted) return;
    setState(() {
      _accessSkipped = skipped;
      _accessReady = true;
    });
  }

  /// Back to the access screen from the softphone (web, signed out).
  bool get _signInAvailable => _accessGate && !_mnscloud.signedIn;

  void _openAccessScreen() {
    unawaited(writeAccessSkipped(false));
    setState(() => _accessSkipped = false);
  }

  void _continueWithoutAccount() {
    unawaited(writeAccessSkipped(true));
    setState(() => _accessSkipped = true);
  }

  void _onMnscloudChanged() {
    if (mounted) setState(() {});
    unawaited(_syncMnscloudLines());
  }

  /// Mirrors the lines of the MNSCloud session as managed accounts (memory only). The secret of
  /// each line is fetched on demand and dropped with the account.
  Future<void> _syncMnscloudLines() async {
    if (_syncingLines) {
      _syncAgain = true;
      return;
    }
    _syncingLines = true;
    try {
      do {
        _syncAgain = false;
        await _applyMnscloudLines();
      } while (_syncAgain && mounted);
    } finally {
      _syncingLines = false;
    }
  }

  Future<void> _applyMnscloudLines() async {
    final wanted = _mnscloud.signedIn
        ? {
            for (final line in _mnscloud.lines.where((l) => l.webrtcReady))
              '$_managedPrefix${line.lineKey}': line,
          }
        : <String, MnscloudLine>{};
    final removed = _accounts
        .where((account) => account.managed && !wanted.containsKey(account.id))
        .toList();
    if (removed.isNotEmpty) {
      final active = _selectedAccount;
      final activeRemoved =
          active != null &&
          removed.any((account) => account.id == active.id) &&
          (active.status == RegistrationStatus.registered ||
              active.status == RegistrationStatus.registering);
      if (!mounted) return;
      setState(() {
        _accounts.removeWhere(
          (account) => removed.any((gone) => gone.id == account.id),
        );
        if (_selectedAccountId != null &&
            removed.any((gone) => gone.id == _selectedAccountId)) {
          _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;
        }
      });
      if (activeRemoved) await _voip.unregister();
    }
    for (final entry in wanted.entries) {
      if (_accounts.any((account) => account.id == entry.key)) continue;
      final credentials = await _mnscloud.lineCredentials(entry.value.lineKey);
      if (credentials == null || !mounted || !_mnscloud.signedIn) continue;
      final account = WebRtcAccount(
        id: entry.key,
        name:
            'MNSCloud · ${credentials.label.isEmpty ? credentials.username : credentials.label}',
        displayName:
            credentials.displayName ??
            _mnscloud.session?.displayName ??
            credentials.username,
        username: credentials.username,
        password: credentials.password,
        domain: credentials.domain,
        wssServer: credentials.wssUrl,
        stunServer: credentials.stunUrls.isEmpty
            ? ''
            : credentials.stunUrls.first,
        turnServer: credentials.turnUrls.isEmpty
            ? ''
            : credentials.turnUrls.first,
        iceServers: credentials.iceServers,
        iceExpiresAt: credentials.iceExpiresAt,
        hasPassword: true,
        allowInsecureTransport: false,
        codecPolicy: WebRtcCodecPolicy.automaticRecommended,
        enabled: false,
        autoRegister: true,
        status: RegistrationStatus.offline,
        managedBy: 'MNSCloud',
      );
      setState(() => _accounts.add(account));
      // Register the primary (or first) company line when nothing else is active.
      final busy = _accounts.any(
        (item) =>
            item.status == RegistrationStatus.registered ||
            item.status == RegistrationStatus.registering,
      );
      if (!busy && (entry.value.primary || wanted.length == 1)) {
        setState(() {
          _selectedAccountId = account.id;
          _enforceSingleActiveAccount(account.id);
        });
        await _voip.register(account);
      }
    }
  }

  /// TURN credentials of company lines are short-lived: fetch a new bundle
  /// within the last hour and swap it in (the next call uses it; an active
  /// registration is kept).
  Future<void> _refreshManagedIce() async {
    if (!_mnscloud.signedIn) return;
    final soon = DateTime.now().add(const Duration(hours: 1));
    final due = _accounts
        .where(
          (account) =>
              account.managed &&
              account.iceExpiresAt != null &&
              account.iceExpiresAt!.isBefore(soon),
        )
        .toList();
    for (final account in due) {
      final lineKey = account.id.substring(_managedPrefix.length);
      final credentials = await _mnscloud.lineCredentials(lineKey);
      if (credentials == null || !mounted || !_mnscloud.signedIn) continue;
      final index = _accounts.indexWhere((item) => item.id == account.id);
      if (index < 0) continue;
      final updated = _accounts[index].copyWith(
        iceServers: credentials.iceServers,
        iceExpiresAt: credentials.iceExpiresAt,
      );
      setState(() => _accounts[index] = updated);
      // Same account key while registered: the controller swaps the account in
      // place without a new REGISTER.
      if (_voip.account?.id == updated.id && _voip.isRegistered) {
        await _voip.register(updated);
      }
    }
  }

  void _focusFromBridge(String? number) {
    if (!mounted) return;
    setState(() {
      if (number != null) _dialNumber = number;
      _mobileTabIndex = 0;
    });
  }

  bool _refuseManaged(WebRtcAccount? account) {
    if (account == null || !account.managed) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Managed line of your company in MNSCloud: it cannot be edited or removed here.',
          ),
        ),
      ),
    );
    return true;
  }

  Future<void> _saveStandaloneContacts() {
    _standaloneDirty = true;
    return _store.saveContacts(_contacts);
  }

  Future<void> _saveStandaloneHistory() {
    _standaloneDirty = true;
    return _store.saveCallHistory(_callHistory);
  }

  Future<void> _openAccountDialog({WebRtcAccount? account}) async {
    if (_refuseManaged(account)) return;
    final result = await showDialog<WebRtcAccount>(
      context: context,
      builder: (context) => AccountDialog(account: account),
    );

    if (result == null) {
      return;
    }

    setState(() {
      final index = _accounts.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _accounts[index] = result;
        _lastEvent = tr('{name} updated', {'name': result.name});
      } else {
        _accounts.add(result);
        _selectedAccountId = result.id;
        _lastEvent = tr('{name} added', {'name': result.name});
      }
      if (result.enabled) {
        _enforceSingleActiveAccount(result.id);
      }
    });
    await _saveStandaloneAccounts();

    if (result.autoRegister && result.enabled) {
      await _voip.register(result);
    }
  }

  Future<void> _removeAccount(WebRtcAccount account) async {
    if (_refuseManaged(account)) return;
    setState(() {
      _accounts.removeWhere((item) => item.id == account.id);
      if (_selectedAccountId == account.id) {
        _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;
      }
      _lastEvent = tr('{name} removed', {'name': account.name});
    });
    await _saveStandaloneAccounts();
  }

  Future<void> _toggleRegistration(WebRtcAccount account) async {
    if (account.status == RegistrationStatus.registered ||
        account.status == RegistrationStatus.registering) {
      setState(() {
        final index = _accounts.indexWhere((item) => item.id == account.id);
        if (index >= 0) {
          _accounts[index] = _accounts[index].copyWith(enabled: false);
        }
      });
      await _saveStandaloneAccounts();
      await _voip.unregister();
      return;
    }

    setState(() {
      _selectedAccountId = account.id;
      _enforceSingleActiveAccount(account.id);
    });
    await _saveStandaloneAccounts();
    await _voip.register(account);
  }

  void _enforceSingleActiveAccount(String activeAccountId) {
    for (var index = 0; index < _accounts.length; index += 1) {
      final account = _accounts[index];
      if (account.id == activeAccountId) {
        _accounts[index] = account.copyWith(enabled: true);
        continue;
      }
      _accounts[index] = account.copyWith(
        enabled: false,
        status: RegistrationStatus.offline,
        diagnostic: RegistrationDiagnostic.stopped(),
      );
    }
  }

  void _syncVoipState() {
    setState(() {
      _trackCallState();
      final activeAccount = _voip.account;
      if (activeAccount != null) {
        final index = _accounts.indexWhere(
          (item) => item.id == activeAccount.id,
        );
        if (index >= 0) {
          _accounts[index] = _accounts[index].copyWith(
            status: _voip.registrationStatus,
            diagnostic: _voip.registrationDiagnostic,
          );
        }
      }
      _lastEvent = _voip.lastEvent;
    });
    _saveStandaloneAccounts();
    _saveStandaloneHistory();
  }

  void _trackCallState() {
    if (_voip.hasActiveCall) {
      if (!_hadActiveCall) {
        _trackedCallStartedAt = DateTime.now();
        _trackedCallRemote = _voip.remoteIdentity;
        _trackedCallIncoming = _voip.activeCallDirection == Direction.incoming;
        _trackedCallAccountName = _selectedAccount?.name ?? '';
        _trackedCallDiagnostic = '';
        _trackedCallEstablished = false;
      }
      if (_voip.lastCallDiagnostic.isNotEmpty) {
        _trackedCallDiagnostic = _voip.lastCallDiagnostic;
      }
      if (_voip.hasEstablishedCall) {
        _trackedCallEstablished = true;
      }
      _hadActiveCall = true;
      return;
    }

    if (!_hadActiveCall) return;

    final startedAt = _trackedCallStartedAt ?? DateTime.now();
    final duration = DateTime.now().difference(startedAt).inSeconds;
    final status = _trackedCallEstablished
        ? PhoneCallStatus.completed
        : (_trackedCallIncoming
              ? PhoneCallStatus.missed
              : PhoneCallStatus.failed);
    _callHistory.insert(
      0,
      PhoneCallHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        remoteIdentity: _trackedCallRemote.isEmpty
            ? tr('Unknown')
            : _trackedCallRemote,
        direction: _trackedCallIncoming
            ? PhoneCallDirection.incoming
            : PhoneCallDirection.outgoing,
        status: status,
        startedAt: startedAt,
        durationSeconds: duration < 0 ? 0 : duration,
        accountName: _trackedCallAccountName,
        diagnostic: _trackedCallDiagnostic,
      ),
    );
    if (_callHistory.length > 250) {
      _callHistory.removeRange(250, _callHistory.length);
    }
    _hadActiveCall = false;
    _trackedCallEstablished = false;
    _trackedCallIncoming = false;
    _trackedCallRemote = '';
    _trackedCallAccountName = '';
    _trackedCallDiagnostic = '';
    _trackedCallStartedAt = null;
  }

  void _appendDial(String value) {
    _keypadTonePlayer.play(value);

    if (_voip.hasActiveCall) {
      _voip.sendDtmf(value);
    }

    setState(() {
      _dialNumber = '$_dialNumber$value';
    });
  }

  void _backspaceDial() {
    if (_dialNumber.isEmpty) {
      return;
    }

    setState(() {
      _dialNumber = _dialNumber.substring(0, _dialNumber.length - 1);
    });
  }

  void _clearDial() {
    setState(() {
      _dialNumber = '';
    });
  }

  Future<void> _makeCall() async {
    final account = _selectedAccount;
    if (account == null || _dialNumber.trim().isEmpty) {
      return;
    }

    await _voip.makeCall(_dialNumber);
  }

  Future<void> _openContactDialog({
    PhoneContact? contact,
    String initialName = '',
    String initialNumber = '',
  }) async {
    final result = await showDialog<PhoneContact>(
      context: context,
      builder: (context) => ContactDialog(
        contact: contact,
        initialName: initialName,
        initialNumber: initialNumber,
      ),
    );
    if (result == null) return;

    setState(() {
      final index = _contacts.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _contacts[index] = result;
      } else {
        _contacts.add(result);
      }
      _lastEvent = tr('{name} saved', {'name': result.name});
    });
    await _saveStandaloneContacts();
  }

  Future<void> _addHistoryEntryToContacts(PhoneCallHistoryEntry entry) async {
    final number = _dialableHistoryIdentity(entry.remoteIdentity);
    if (number.isEmpty || _contactForHistoryEntry(entry) != null) {
      return;
    }

    await _openContactDialog(initialName: number, initialNumber: number);
  }

  void _dialContact(PhoneContact contact) {
    setState(() {
      _dialNumber = contact.number;
      _mobileTabIndex = 0;
    });
  }

  void _dialHistoryEntry(PhoneCallHistoryEntry entry) {
    setState(() {
      _dialNumber = _dialableHistoryIdentity(entry.remoteIdentity);
      _mobileTabIndex = 0;
    });
  }

  Future<void> _removeHistoryEntry(PhoneCallHistoryEntry entry) async {
    setState(() {
      _callHistory.removeWhere((item) => item.id == entry.id);
      _lastEvent = tr('Call history entry removed');
    });
    await _saveStandaloneHistory();
  }

  Future<void> _clearCallHistory() async {
    if (_callHistory.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Clear call history?')),
        content: Text(
          tr(
            tr(
              'This will remove {n} local call history entries from this device.',
            ),
            {'n': _callHistory.length},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(tr('Clear history')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _callHistory.clear();
      _lastEvent = tr('Call history cleared');
    });
    await _saveStandaloneHistory();
  }

  PhoneContact? _contactForHistoryEntry(PhoneCallHistoryEntry entry) {
    final entryNumber = _normalizePhoneNumber(
      _dialableHistoryIdentity(entry.remoteIdentity),
    );
    if (entryNumber.isEmpty) return null;

    for (final contact in _contacts) {
      if (_normalizePhoneNumber(contact.number) == entryNumber) {
        return contact;
      }
    }
    return null;
  }

  Future<void> _openSettingsDialog() async {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final settings = PhoneWebSettingsDialog(
      voip: _voip,
      mnscloud: _mnscloud,
      accounts: _accounts,
      runtimeVersion: _runtimeVersion,
      onRefreshVersion: _refreshRuntimeVersion,
    );

    if (compact) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => settings,
      );
      return;
    }

    await showDialog<void>(context: context, builder: (context) => settings);
  }

  Future<void> _syncNativeContacts() async {
    if (_contactsSyncing) return;

    setState(() {
      _contactsSyncing = true;
    });

    final result = await _contactsRepository.loadContacts();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(result.message)));

    setState(() {
      _contactsSyncing = false;
      _lastEvent = result.message;

      final shouldSaveContacts = result.status == NativeContactsStatus.loaded;
      if (shouldSaveContacts) {
        final manualContacts = _contacts
            .where((contact) => contact.source == PhoneContactSource.manual)
            .toList();
        _contacts
          ..clear()
          ..addAll(manualContacts)
          ..addAll(result.contacts);
      }
    });
    if (result.status == NativeContactsStatus.loaded) {
      await _saveStandaloneContacts();
    }
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_accessGate && !_accessSkipped && !_mnscloud.signedIn) {
      if (!_accessReady) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return PhoneWebAccessScreen(
        controller: _mnscloud,
        onContinueWithout: _continueWithoutAccount,
      );
    }
    final shell = _buildShell(context);
    // Never interrupt a call: the notice waits until the call ends.
    if (!_update.noticeVisible || _voip.hasActiveCall) return shell;
    final mobile = MediaQuery.sizeOf(context).width < 640;
    final notice = AppUpdateNotice(controller: _update);
    return Stack(
      children: [
        shell,
        if (mobile)
          Positioned(
            left: 8,
            right: 8,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(child: notice),
              ),
            ),
          )
        else
          Positioned(right: 24, bottom: 24, child: notice),
      ],
    );
  }

  Widget _buildShell(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 640) {
      return MobilePhoneShell(
        accounts: _accounts,
        contacts: _contacts,
        callHistory: _callHistory,
        selectedAccount: _selectedAccount,
        dialNumber: _dialNumber,
        voip: _voip,
        currentIndex: _mobileTabIndex,
        lastEvent: _lastEvent,
        onTabChanged: (index) => setState(() => _mobileTabIndex = index),
        onAppend: _appendDial,
        onBackspace: _backspaceDial,
        onClear: _clearDial,
        onCall: _makeCall,
        onOpenSettings: _openSettingsDialog,
        onSignIn: _signInAvailable ? _openAccessScreen : null,
        onAddAccount: () => _openAccountDialog(),
        onEditAccount: (account) => _openAccountDialog(account: account),
        onRemoveAccount: _removeAccount,
        onSelectAccount: (account) {
          setState(() {
            _selectedAccountId = account.id;
          });
          _saveStandaloneAccounts();
        },
        onToggleRegistration: _toggleRegistration,
        onAddContact: () => _openContactDialog(),
        onEditContact: (contact) => _openContactDialog(contact: contact),
        onDialContact: _dialContact,
        onDialHistoryEntry: _dialHistoryEntry,
        onAddHistoryContact: _addHistoryEntryToContacts,
        onRemoveHistoryEntry: _removeHistoryEntry,
        onClearCallHistory: _clearCallHistory,
        contactForHistoryEntry: _contactForHistoryEntry,
        onSyncContacts: _syncNativeContacts,
        contactsSyncing: _contactsSyncing,
      );
    }

    final compact = width < 920;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                accountCount: _accounts.length,
                onOpenSettings: _openSettingsDialog,
                onAddAccount: () => _openAccountDialog(),
                onSignIn: _signInAvailable ? _openAccessScreen : null,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: compact
                    ? ListView(children: _buildPanels(compact: true))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: Column(
                              children: [
                                Expanded(
                                  child: AccountPanel(
                                    accounts: _accounts,
                                    selectedAccountId: _selectedAccount?.id,
                                    useInternalScroll: true,
                                    onAddAccount: () => _openAccountDialog(),
                                    onEditAccount: (account) =>
                                        _openAccountDialog(account: account),
                                    onRemoveAccount: _removeAccount,
                                    onSelectAccount: (account) {
                                      setState(() {
                                        _selectedAccountId = account.id;
                                      });
                                      _saveStandaloneAccounts();
                                    },
                                    onToggleRegistration: _toggleRegistration,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ContactsSummaryPanel(
                                    contacts: _contacts,
                                    contactsSyncing: _contactsSyncing,
                                    useInternalScroll: true,
                                    onAddContact: () => _openContactDialog(),
                                    onSyncContacts: _syncNativeContacts,
                                    onEditContact: (contact) =>
                                        _openContactDialog(contact: contact),
                                    onDialContact: _dialContact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: WorkspacePanels(
                              selectedAccount: _selectedAccount,
                              dialNumber: _dialNumber,
                              voip: _voip,
                              onAppend: _appendDial,
                              onBackspace: _backspaceDial,
                              onClear: _clearDial,
                              onCall: _makeCall,
                              callHistory: _callHistory,
                              onDialHistoryEntry: _dialHistoryEntry,
                              onAddHistoryContact: _addHistoryEntryToContacts,
                              onRemoveHistoryEntry: _removeHistoryEntry,
                              onClearCallHistory: _clearCallHistory,
                              contactForHistoryEntry: _contactForHistoryEntry,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPanels({required bool compact}) {
    return [
      AccountPanel(
        accounts: _accounts,
        selectedAccountId: _selectedAccount?.id,
        onAddAccount: () => _openAccountDialog(),
        onEditAccount: (account) => _openAccountDialog(account: account),
        onRemoveAccount: _removeAccount,
        onSelectAccount: (account) {
          setState(() {
            _selectedAccountId = account.id;
          });
          _saveStandaloneAccounts();
        },
        onToggleRegistration: _toggleRegistration,
      ),
      const SizedBox(height: 16),
      ContactsSummaryPanel(
        contacts: _contacts,
        contactsSyncing: _contactsSyncing,
        onAddContact: () => _openContactDialog(),
        onSyncContacts: _syncNativeContacts,
        onEditContact: (contact) => _openContactDialog(contact: contact),
        onDialContact: _dialContact,
      ),
      const SizedBox(height: 16),
      DialerPanel(
        selectedAccount: _selectedAccount,
        dialNumber: _dialNumber,
        voip: _voip,
        onAppend: _appendDial,
        onBackspace: _backspaceDial,
        onClear: _clearDial,
        onCall: _makeCall,
      ),
      const SizedBox(height: 16),
      CallHistoryPanel(
        entries: _callHistory,
        onDial: _dialHistoryEntry,
        onAddContact: _addHistoryEntryToContacts,
        onRemove: _removeHistoryEntry,
        onClearAll: _clearCallHistory,
        contactForEntry: _contactForHistoryEntry,
      ),
      const SizedBox(height: 16),
      const MessagesPanel(),
    ];
  }
}

class WorkspacePanels extends StatelessWidget {
  const WorkspacePanels({
    required this.selectedAccount,
    required this.dialNumber,
    required this.voip,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    required this.callHistory,
    required this.onDialHistoryEntry,
    required this.onAddHistoryContact,
    required this.onRemoveHistoryEntry,
    required this.onClearCallHistory,
    required this.contactForHistoryEntry,
    super.key,
  });

  final WebRtcAccount? selectedAccount;
  final String dialNumber;
  final PhoneWebVoipController voip;
  final List<PhoneCallHistoryEntry> callHistory;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;
  final ValueChanged<PhoneCallHistoryEntry> onDialHistoryEntry;
  final ValueChanged<PhoneCallHistoryEntry> onAddHistoryContact;
  final ValueChanged<PhoneCallHistoryEntry> onRemoveHistoryEntry;
  final VoidCallback onClearCallHistory;
  final PhoneContact? Function(PhoneCallHistoryEntry entry)
  contactForHistoryEntry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1080) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DialerPanel(
                  selectedAccount: selectedAccount,
                  dialNumber: dialNumber,
                  voip: voip,
                  onAppend: onAppend,
                  onBackspace: onBackspace,
                  onClear: onClear,
                  onCall: onCall,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    Expanded(
                      child: CallHistoryPanel(
                        entries: callHistory,
                        contactForEntry: contactForHistoryEntry,
                        onDial: onDialHistoryEntry,
                        onAddContact: onAddHistoryContact,
                        onRemove: onRemoveHistoryEntry,
                        onClearAll: onClearCallHistory,
                        useInternalScroll: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: MessagesPanel(useInternalScroll: true)),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          children: [
            DialerPanel(
              selectedAccount: selectedAccount,
              dialNumber: dialNumber,
              voip: voip,
              onAppend: onAppend,
              onBackspace: onBackspace,
              onClear: onClear,
              onCall: onCall,
            ),
            const SizedBox(height: 16),
            CallHistoryPanel(
              entries: callHistory,
              contactForEntry: contactForHistoryEntry,
              onDial: onDialHistoryEntry,
              onAddContact: onAddHistoryContact,
              onRemove: onRemoveHistoryEntry,
              onClearAll: onClearCallHistory,
            ),
            const SizedBox(height: 16),
            MessagesPanel(),
          ],
        );
      },
    );
  }
}

class MobilePhoneShell extends StatelessWidget {
  const MobilePhoneShell({
    required this.accounts,
    required this.contacts,
    required this.callHistory,
    required this.selectedAccount,
    required this.dialNumber,
    required this.voip,
    required this.currentIndex,
    required this.lastEvent,
    required this.onTabChanged,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    required this.onOpenSettings,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onRemoveAccount,
    required this.onSelectAccount,
    required this.onToggleRegistration,
    required this.onAddContact,
    required this.onEditContact,
    required this.onDialContact,
    required this.onDialHistoryEntry,
    required this.onAddHistoryContact,
    required this.onRemoveHistoryEntry,
    required this.onClearCallHistory,
    required this.contactForHistoryEntry,
    required this.onSyncContacts,
    required this.contactsSyncing,
    this.onSignIn,
    super.key,
  });

  final VoidCallback? onSignIn;
  final List<WebRtcAccount> accounts;
  final List<PhoneContact> contacts;
  final List<PhoneCallHistoryEntry> callHistory;
  final WebRtcAccount? selectedAccount;
  final String dialNumber;
  final PhoneWebVoipController voip;
  final int currentIndex;
  final String lastEvent;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddAccount;
  final ValueChanged<WebRtcAccount> onEditAccount;
  final ValueChanged<WebRtcAccount> onRemoveAccount;
  final ValueChanged<WebRtcAccount> onSelectAccount;
  final ValueChanged<WebRtcAccount> onToggleRegistration;
  final VoidCallback onAddContact;
  final ValueChanged<PhoneContact> onEditContact;
  final ValueChanged<PhoneContact> onDialContact;
  final ValueChanged<PhoneCallHistoryEntry> onDialHistoryEntry;
  final ValueChanged<PhoneCallHistoryEntry> onAddHistoryContact;
  final ValueChanged<PhoneCallHistoryEntry> onRemoveHistoryEntry;
  final VoidCallback onClearCallHistory;
  final PhoneContact? Function(PhoneCallHistoryEntry entry)
  contactForHistoryEntry;
  final VoidCallback onSyncContacts;
  final bool contactsSyncing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;
    final pages = [
      MobileDialerView(
        dialNumber: dialNumber,
        voip: voip,
        selectedAccount: selectedAccount,
        onAppend: onAppend,
        onBackspace: onBackspace,
        onClear: onClear,
        onCall: onCall,
      ),
      MobileContactsView(
        contacts: contacts,
        onAddContact: onAddContact,
        onEditContact: onEditContact,
        onDialContact: onDialContact,
        onSyncContacts: onSyncContacts,
        contactsSyncing: contactsSyncing,
      ),
      MobileHistoryView(
        entries: callHistory,
        onDial: onDialHistoryEntry,
        onAddContact: onAddHistoryContact,
        onRemove: onRemoveHistoryEntry,
        onClearAll: onClearCallHistory,
        contactForEntry: contactForHistoryEntry,
      ),
      MobileMessagesView(),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            MobileTopBar(
              onSignIn: onSignIn,
              account: selectedAccount,
              accountCount: accounts.length,
              onSettings: onOpenSettings,
              onAccounts: () => _showAccountsSheet(context),
            ),
            Expanded(child: pages[currentIndex]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected)
                  ? selectedColor
                  : unselectedColor,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? selectedColor
                  : unselectedColor,
            ),
          ),
        ),
        child: NavigationBar(
          height: 78,
          backgroundColor: colorScheme.surfaceContainerHighest,
          selectedIndex: currentIndex,
          onDestinationSelected: onTabChanged,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dialpad),
              label: tr('Phone'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: tr('Contacts'),
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: tr('History'),
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              label: tr('Messages'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return AccountsBottomSheet(
          accounts: accounts,
          selectedAccount: selectedAccount,
          onAddAccount: () {
            Navigator.pop(context);
            onAddAccount();
          },
          onEditAccount: (account) {
            Navigator.pop(context);
            onEditAccount(account);
          },
          onSelectAccount: (account) {
            onSelectAccount(account);
            Navigator.pop(context);
          },
          onToggleRegistration: onToggleRegistration,
        );
      },
    );
  }
}

class AccountsBottomSheet extends StatefulWidget {
  const AccountsBottomSheet({
    required this.accounts,
    required this.selectedAccount,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onSelectAccount,
    required this.onToggleRegistration,
    super.key,
  });

  final List<WebRtcAccount> accounts;
  final WebRtcAccount? selectedAccount;
  final VoidCallback onAddAccount;
  final ValueChanged<WebRtcAccount> onEditAccount;
  final ValueChanged<WebRtcAccount> onSelectAccount;
  final ValueChanged<WebRtcAccount> onToggleRegistration;

  @override
  State<AccountsBottomSheet> createState() => _AccountsBottomSheetState();
}

class _AccountsBottomSheetState extends State<AccountsBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = widget.accounts
        .where((account) => _matchesAccount(account, _searchController.text))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tr('Accounts'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onAddAccount,
                    tooltip: tr('Add account'),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SearchBox(
                controller: _searchController,
                hintText: tr('Search accounts'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (widget.accounts.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text(tr('No WebRTC accounts'))),
                )
              else if (filteredAccounts.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(tr('No accounts match your search.')),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: filteredAccounts
                        .map(
                          (account) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(account.name),
                            subtitle: Text(
                              account.diagnostic == null
                                  ? '${account.username}@${account.domain}'
                                  : '${account.username}@${account.domain}\n${account.diagnostic!.summary}',
                            ),
                            isThreeLine: account.diagnostic != null,
                            leading: Icon(
                              widget.selectedAccount?.id == account.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      widget.onToggleRegistration(account),
                                  tooltip:
                                      account.status ==
                                          RegistrationStatus.registered
                                      ? tr('Disconnect account')
                                      : tr('Register account'),
                                  icon: Icon(
                                    account.status ==
                                            RegistrationStatus.registered
                                        ? Icons.logout
                                        : Icons.login,
                                  ),
                                ),
                                if (account.diagnostic != null)
                                  IconButton(
                                    onPressed: () =>
                                        _showRegistrationDiagnosticDialog(
                                          context,
                                          account,
                                        ),
                                    tooltip: tr('Registration details'),
                                    icon: const Icon(Icons.info_outline),
                                  ),
                                IconButton(
                                  onPressed: () =>
                                      widget.onEditAccount(account),
                                  tooltip: tr('Edit account'),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                            onTap: () => widget.onSelectAccount(account),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileTopBar extends StatelessWidget {
  const MobileTopBar({
    required this.account,
    required this.accountCount,
    required this.onSettings,
    required this.onAccounts,
    this.onSignIn,
    super.key,
  });

  final WebRtcAccount? account;
  final int accountCount;
  final VoidCallback onSettings;
  final VoidCallback onAccounts;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final currentAccount = account;
    final statusLabel = switch (currentAccount?.status) {
      RegistrationStatus.registered => tr('Registered'),
      RegistrationStatus.registering => tr('Registering'),
      RegistrationStatus.failed => tr('Failed'),
      RegistrationStatus.offline => tr('No service'),
      null => tr('No service'),
    };
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onAccounts,
                icon: const Icon(Icons.menu, size: 32),
              ),
              if (accountCount == 0)
                const Positioned(
                  right: 7,
                  top: 8,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text('!', style: TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  currentAccount == null
                      ? tr('No account')
                      : currentAccount.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onSignIn != null)
            IconButton(
              key: const Key('mobileSignIn'),
              onPressed: onSignIn,
              tooltip: tr('Sign in'),
              icon: const Icon(Icons.login),
            ),
          const InstallAppButton(),
          IconButton(
            onPressed: onSettings,
            tooltip: tr('Settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class MobileDialerView extends StatelessWidget {
  const MobileDialerView({
    required this.dialNumber,
    required this.voip,
    required this.selectedAccount,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    super.key,
  });

  final String dialNumber;
  final PhoneWebVoipController voip;
  final WebRtcAccount? selectedAccount;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canCall =
        selectedAccount != null &&
        voip.registrationStatus == RegistrationStatus.registered &&
        dialNumber.trim().isNotEmpty &&
        !voip.hasActiveCall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final tightHeight = availableHeight < 520;
        final compactHeight = availableHeight < 640;
        final callButtonSize = tightHeight
            ? 48.0
            : compactHeight
            ? 56.0
            : 66.0;
        final brandIconSize = tightHeight
            ? 34.0
            : compactHeight
            ? 50.0
            : 76.0;
        final brandFontSize = tightHeight
            ? 22.0
            : compactHeight
            ? 28.0
            : 36.0;
        final numberFontSize = tightHeight
            ? 28.0
            : compactHeight
            ? 34.0
            : 42.0;
        final contentPadding = tightHeight
            ? 4.0
            : compactHeight
            ? 8.0
            : 16.0;
        final preferredDialKeyHeight = tightHeight
            ? 48.0
            : compactHeight
            ? 58.0
            : 74.0;
        final topAreaHeight = tightHeight
            ? 76.0
            : compactHeight
            ? 112.0
            : 154.0;
        final controlsHeight =
            callButtonSize +
            (voip.hasActiveCall ? 78.0 : 0.0) +
            (tightHeight
                ? 14.0
                : compactHeight
                ? 18.0
                : 26.0);
        final dialPadChrome = tightHeight
            ? 14.0
            : compactHeight
            ? 20.0
            : 34.0;
        final maxDialKeyHeight =
            ((availableHeight -
                        topAreaHeight -
                        controlsHeight -
                        dialPadChrome) /
                    4)
                .clamp(42.0, 78.0)
                .toDouble();
        final dialKeyHeight = preferredDialKeyHeight > maxDialKeyHeight
            ? maxDialKeyHeight
            : preferredDialKeyHeight;

        return Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: dialNumber.isEmpty
                        ? Column(
                            key: const ValueKey('brand'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.wifi_calling_3_outlined,
                                size: brandIconSize,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(
                                height: tightHeight
                                    ? 4
                                    : compactHeight
                                    ? 6
                                    : 12,
                              ),
                              Text(
                                'MNSCloud',
                                style: TextStyle(
                                  fontSize: brandFontSize,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            key: const ValueKey('number'),
                            dialNumber,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: numberFontSize,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                tightHeight
                    ? 2
                    : compactHeight
                    ? 6
                    : 16,
                8,
                2,
              ),
              child: MobileDialPad(
                keyHeight: dialKeyHeight,
                onAppend: onAppend,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                0,
                8,
                tightHeight
                    ? 4
                    : compactHeight
                    ? 6
                    : 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: MobileUtilityButton(
                        icon: Icons.voicemail,
                        label: '',
                        compact: compactHeight,
                        onPressed: () => onAppend('*97'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: callButtonSize,
                        height: callButtonSize,
                        child: FilledButton(
                          onPressed: canCall ? onCall : null,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: colorScheme.secondary,
                            disabledBackgroundColor:
                                colorScheme.surfaceContainerHighest,
                            padding: EdgeInsets.zero,
                          ),
                          child: Icon(
                            Icons.call,
                            size: compactHeight ? 26 : 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: MobileUtilityButton(
                        icon: Icons.backspace_outlined,
                        label: '',
                        compact: compactHeight,
                        onPressed: dialNumber.isEmpty ? null : onBackspace,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (voip.hasActiveCall)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: ActiveCallControls(voip: voip),
              ),
          ],
        );
      },
    );
  }
}

class MobileDialPad extends StatelessWidget {
  const MobileDialPad({required this.onAppend, this.keyHeight = 86, super.key});

  final ValueChanged<String> onAppend;
  final double keyHeight;

  static const keys = [
    ('1', ''),
    ('2', 'ABC'),
    ('3', 'DEF'),
    ('4', 'GHI'),
    ('5', 'JKL'),
    ('6', 'MNO'),
    ('7', 'PQRS'),
    ('8', 'TUV'),
    ('9', 'WXYZ'),
    ('*', ''),
    ('0', '+'),
    ('#', ''),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: keyHeight,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        return TextButton(
          onPressed: () => onAppend(key.$1),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                key.$1,
                style: TextStyle(
                  fontSize: keyHeight < 46
                      ? 26
                      : keyHeight < 52
                      ? 30
                      : keyHeight < 68
                      ? 34
                      : 40,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
              SizedBox(
                height: keyHeight < 46
                    ? 12
                    : keyHeight < 52
                    ? 16
                    : 20,
                child: Text(
                  key.$2,
                  style: TextStyle(
                    fontSize: keyHeight < 46
                        ? 10
                        : keyHeight < 52
                        ? 11
                        : 13,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MobileUtilityButton extends StatelessWidget {
  const MobileUtilityButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(
          alpha: 0.52,
        ),
        minimumSize: Size(compact ? 64 : 78, compact ? 54 : 64),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 28 : 34,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
          ),
          Text(
            label.isEmpty ? ' ' : label,
            style: TextStyle(
              color: enabled
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileContactsView extends StatefulWidget {
  const MobileContactsView({
    required this.contacts,
    required this.onAddContact,
    required this.onEditContact,
    required this.onDialContact,
    required this.onSyncContacts,
    required this.contactsSyncing,
    super.key,
  });

  final List<PhoneContact> contacts;
  final VoidCallback onAddContact;
  final ValueChanged<PhoneContact> onEditContact;
  final ValueChanged<PhoneContact> onDialContact;
  final VoidCallback onSyncContacts;
  final bool contactsSyncing;

  @override
  State<MobileContactsView> createState() => _MobileContactsViewState();
}

class _MobileContactsViewState extends State<MobileContactsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredContacts = widget.contacts
        .where((contact) => _matchesContact(contact, _searchController.text))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                tr('Contacts'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.contactsSyncing
                    ? null
                    : widget.onSyncContacts,
                tooltip: tr('Sync device address book'),
                icon: widget.contactsSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
              ),
              IconButton(
                onPressed: widget.onAddContact,
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchBox(
            controller: _searchController,
            hintText: tr('Search contact'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 72,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(tr('No contacts')),
                        const SizedBox(height: 4),
                        Text(
                          tr('Add contacts to dial faster.'),
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: widget.contactsSyncing
                              ? null
                              : widget.onSyncContacts,
                          icon: widget.contactsSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync_outlined),
                          label: Text(tr('Sync address book')),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: widget.onAddContact,
                          icon: const Icon(Icons.add),
                          label: Text(tr('Add contact')),
                        ),
                      ],
                    ),
                  )
                : filteredContacts.isEmpty
                ? MobileEmptyTab(
                    icon: Icons.search_off_outlined,
                    title: tr('No contact found'),
                    message: tr('Try searching by name, company or number.'),
                  )
                : ListView.separated(
                    itemCount: filteredContacts.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: colorScheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Text(
                            contact.name.isEmpty ? '?' : contact.name[0],
                          ),
                        ),
                        title: Text(contact.name),
                        subtitle: Text(
                          contact.company.isEmpty
                              ? contact.number
                              : '${contact.company} · ${contact.number}',
                        ),
                        isThreeLine:
                            contact.source == PhoneContactSource.native,
                        trailing: Wrap(
                          children: [
                            if (contact.source == PhoneContactSource.native)
                              Tooltip(
                                message: tr('Contact synced from the device'),
                                child: Icon(Icons.contacts_outlined, size: 20),
                              ),
                            IconButton(
                              onPressed: () => widget.onEditContact(contact),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => widget.onDialContact(contact),
                              icon: const Icon(Icons.call_outlined),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MobileHistoryView extends StatefulWidget {
  const MobileHistoryView({
    required this.entries,
    required this.onDial,
    required this.onAddContact,
    required this.onRemove,
    required this.onClearAll,
    required this.contactForEntry,
    super.key,
  });

  final List<PhoneCallHistoryEntry> entries;
  final ValueChanged<PhoneCallHistoryEntry> onDial;
  final ValueChanged<PhoneCallHistoryEntry> onAddContact;
  final ValueChanged<PhoneCallHistoryEntry> onRemove;
  final VoidCallback onClearAll;
  final PhoneContact? Function(PhoneCallHistoryEntry entry) contactForEntry;

  @override
  State<MobileHistoryView> createState() => _MobileHistoryViewState();
}

class _MobileHistoryViewState extends State<MobileHistoryView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = widget.entries
        .where(
          (entry) => _matchesCallHistoryEntry(entry, _searchController.text),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Histórico',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.entries.isEmpty ? null : widget.onClearAll,
                tooltip: tr('Clear history'),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchBox(
            controller: _searchController,
            hintText: tr('Search history'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: widget.entries.isEmpty
                ? MobileEmptyTab(
                    icon: Icons.history,
                    title: tr('Empty history'),
                    message: tr('Placed and received calls will appear here.'),
                  )
                : filteredEntries.isEmpty
                ? MobileEmptyTab(
                    icon: Icons.search_off_outlined,
                    title: tr('No call found'),
                    message: tr(
                      'Try searching by number, account, status or SIP.',
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return CallHistoryTile(
                        entry: entry,
                        existingContact: widget.contactForEntry(entry),
                        onDial: () => widget.onDial(entry),
                        onAddContact: () => widget.onAddContact(entry),
                        onRemove: () => widget.onRemove(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MobileMessagesView extends StatelessWidget {
  const MobileMessagesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: MessagesPanel(),
    );
  }
}

class MobileEmptyTab extends StatelessWidget {
  const MobileEmptyTab({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 76, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.accountCount,
    required this.onOpenSettings,
    required this.onAddAccount,
    this.onSignIn,
    super.key,
  });

  final int accountCount;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddAccount;

  /// Opens the MNSCloud access screen; null when signed in or not on the web.
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MNSCloud PhoneWeb',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              accountCount == 1
                  ? tr('1 WebRTC account configured')
                  : tr('{n} WebRTC accounts configured', {'n': accountCount}),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(
          height: compact ? 14 : 0,
          width: compact ? double.infinity : 0,
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            if (onSignIn != null)
              OutlinedButton.icon(
                key: const Key('headerSignIn'),
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: Text(tr('Sign in')),
              ),
            const InstallAppButton(labeled: true),
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text(tr('Settings')),
            ),
            FilledButton.icon(
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
              label: Text(tr('Add account')),
            ),
          ],
        ),
      ],
    );
  }
}

class VersionBadge extends StatelessWidget {
  const VersionBadge({
    required this.versionInfo,
    this.compact = false,
    this.onRefresh,
    super.key,
  });

  final RuntimeVersionInfo versionInfo;
  final bool compact;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final updateAvailable = versionInfo.updateAvailable;
    final foreground = updateAvailable
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSurfaceVariant;
    final background = updateAvailable
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final borderColor = updateAvailable
        ? colorScheme.tertiary
        : colorScheme.outlineVariant;
    final current = versionInfo.displayVersion;
    final latest = versionInfo.latestVersion;
    final tooltip = updateAvailable
        ? 'Current $current · Installed v$latest (reload to update)'
        : latest == null
        ? 'Current $current'
        : 'Current $current · Latest v$latest';

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            updateAvailable ? Icons.system_update_alt : Icons.verified_outlined,
            size: compact ? 14 : 16,
            color: foreground,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            compact
                ? current
                : updateAvailable
                ? '$current → v$latest'
                : current,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: tooltip,
      child: onRefresh == null
          ? badge
          : InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onRefresh,
              child: badge,
            ),
    );
  }
}

enum PhoneWebSettingsSection { mnscloud, interface, audioVideo, debug }

class PhoneWebSettingsDialog extends StatefulWidget {
  const PhoneWebSettingsDialog({
    required this.voip,
    required this.mnscloud,
    required this.accounts,
    required this.runtimeVersion,
    required this.onRefreshVersion,
    super.key,
  });

  final PhoneWebVoipController voip;
  final MnscloudSessionController mnscloud;
  final List<WebRtcAccount> accounts;
  final RuntimeVersionInfo runtimeVersion;
  final VoidCallback onRefreshVersion;

  @override
  State<PhoneWebSettingsDialog> createState() => _PhoneWebSettingsDialogState();
}

class _PhoneWebSettingsDialogState extends State<PhoneWebSettingsDialog> {
  PhoneWebSettingsSection _section = PhoneWebSettingsSection.interface;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;

    if (compact) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.62,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.38,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        tr('Settings'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: tr('Close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _SettingsSectionSelector(
                          selected: _section,
                          onSelected: (section) =>
                              setState(() => _section = section),
                          compact: true,
                        ),
                        const SizedBox(height: 14),
                        _buildSelectedSection(colorScheme),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return AlertDialog(
      title: Text(tr('Settings')),
      content: SizedBox(
        width: 860,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.74,
          ),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SettingsSectionSelector(
                      selected: _section,
                      onSelected: (section) =>
                          setState(() => _section = section),
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    Flexible(child: _buildSelectedSection(colorScheme)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _SettingsSectionSelector(
                        selected: _section,
                        onSelected: (section) =>
                            setState(() => _section = section),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(child: _buildSelectedSection(colorScheme)),
                  ],
                ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Close')),
        ),
      ],
    );
  }

  Widget _buildSelectedSection(ColorScheme colorScheme) {
    return switch (_section) {
      PhoneWebSettingsSection.mnscloud => MnscloudSessionSection(
        controller: widget.mnscloud,
      ),
      PhoneWebSettingsSection.interface => _InterfaceSettingsSection(
        versionInfo: widget.runtimeVersion,
        onRefreshVersion: widget.onRefreshVersion,
      ),
      PhoneWebSettingsSection.audioVideo => const _AudioVideoSettingsSection(),
      PhoneWebSettingsSection.debug => _DebugSettingsSection(
        voip: widget.voip,
        accounts: widget.accounts,
        onChanged: () => setState(() {}),
      ),
    };
  }
}

class _SettingsSectionSelector extends StatelessWidget {
  const _SettingsSectionSelector({
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final PhoneWebSettingsSection selected;
  final ValueChanged<PhoneWebSettingsSection> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      (PhoneWebSettingsSection.mnscloud, Icons.cloud_outlined, 'MNSCloud'),
      (
        PhoneWebSettingsSection.interface,
        Icons.palette_outlined,
        tr('Interface'),
      ),
      (
        PhoneWebSettingsSection.audioVideo,
        Icons.perm_media_outlined,
        tr('Audio and Video'),
      ),
      (PhoneWebSettingsSection.debug, Icons.bug_report_outlined, 'Debug'),
    ];

    if (compact) {
      return Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                selected: selected == item.$1,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: selected == item.$1
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: Icon(item.$2),
                title: Text(
                  item.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected == item.$1
                    ? const Icon(Icons.check_circle_outline)
                    : null,
                onTap: () => onSelected(item.$1),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected: selected == item.$1,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Icon(item.$2),
              title: Text(item.$3),
              onTap: () => onSelected(item.$1),
            ),
          ),
      ],
    );
  }
}

class _InterfaceSettingsSection extends StatelessWidget {
  const _InterfaceSettingsSection({
    required this.versionInfo,
    required this.onRefreshVersion,
  });

  final RuntimeVersionInfo versionInfo;
  final VoidCallback onRefreshVersion;

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      title: tr('Interface'),
      subtitle: tr('Visual preferences of PhoneWeb.'),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.brightness_auto_outlined),
          title: Text(tr('Theme')),
          subtitle: Text(tr('Automatic (system)')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.translate_outlined),
          title: Text(tr('Language')),
          subtitle: Text(
            tr('Language of the screens; follows the device when automatic.'),
          ),
          trailing: DropdownButton<String>(
            key: const Key('settingsLanguage'),
            value: accessLocale.value?.toLanguageTag() ?? 'auto',
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) unawaited(setAccessLocale(value));
            },
            items: [
              DropdownMenuItem(
                value: 'auto',
                child: Text(tr('Automatic (browser/system)')),
              ),
              const DropdownMenuItem(
                value: 'pt-BR',
                child: Text('Português (BR)'),
              ),
              const DropdownMenuItem(
                value: 'en-US',
                child: Text('English (US)'),
              ),
              const DropdownMenuItem(
                value: 'es-ES',
                child: Text('Español (ES)'),
              ),
            ],
          ),
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Version'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            VersionBadge(versionInfo: versionInfo, onRefresh: onRefreshVersion),
          ],
        ),
      ],
    );
  }
}

class _AudioVideoSettingsSection extends StatelessWidget {
  const _AudioVideoSettingsSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      title: tr('Audio and Video'),
      subtitle: tr('Local media settings of the softphone.'),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.mic_none_outlined),
          title: Text(tr('Microphone')),
          subtitle: Text(tr('Uses the default device allowed by the browser.')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.volume_up_outlined),
          title: Text(tr('Audio output')),
          subtitle: Text(tr('Uses the default system/browser output.')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.videocam_outlined),
          title: Text('Vídeo'),
          subtitle: Text(tr('Reserved for future video calls.')),
        ),
      ],
    );
  }
}

class _DebugSettingsSection extends StatelessWidget {
  const _DebugSettingsSection({
    required this.voip,
    required this.accounts,
    required this.onChanged,
  });

  final PhoneWebVoipController voip;
  final List<WebRtcAccount> accounts;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logText = voip.debugLogText(accounts: accounts);

    return _SettingsSectionCard(
      title: 'Debug',
      subtitle: tr(
        'Local diagnostics for SIP/WebRTC, media and screen actions.',
      ),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: voip.debugLoggingEnabled,
          onChanged: (enabled) {
            voip.setDebugLoggingEnabled(enabled);
            onChanged();
          },
          title: Text(tr('Enable detailed debug')),
          subtitle: Text(
            tr(
              'Capture SIP/WebRTC, media, registration and screen events to copy and send for analysis.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            tr('{n} event(s) captured. The buffer keeps the last 600 events.'),
            {'n': voip.debugEvents.length},
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    logText,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                voip.clearDebugLog();
                onChanged();
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(tr('Clear')),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: logText));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(tr('Debug copied'))));
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(tr('Copy')),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return SingleChildScrollView(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class AccountPanel extends StatefulWidget {
  const AccountPanel({
    required this.accounts,
    required this.selectedAccountId,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onRemoveAccount,
    required this.onSelectAccount,
    required this.onToggleRegistration,
    this.useInternalScroll = false,
    super.key,
  });

  final List<WebRtcAccount> accounts;
  final String? selectedAccountId;
  final bool useInternalScroll;
  final VoidCallback onAddAccount;
  final ValueChanged<WebRtcAccount> onEditAccount;
  final ValueChanged<WebRtcAccount> onRemoveAccount;
  final ValueChanged<WebRtcAccount> onSelectAccount;
  final ValueChanged<WebRtcAccount> onToggleRegistration;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = widget.accounts
        .where((account) => _matchesAccount(account, _searchController.text))
        .toList();
    final bodyChildren = <Widget>[
      if (widget.accounts.isEmpty)
        EmptyState(
          icon: Icons.wifi_calling_3_outlined,
          title: tr('No WebRTC accounts'),
          message: tr('Add a WSS provider account to start configuring calls.'),
          actionLabel: tr('Add account'),
          onAction: widget.onAddAccount,
        )
      else if (filteredAccounts.isEmpty)
        EmptyState(
          icon: Icons.search_off_outlined,
          title: tr('No accounts found'),
          message: tr(
            'Search by account name, SIP user, domain, WSS or status.',
          ),
        )
      else
        ...filteredAccounts.map(
          (account) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AccountTile(
              account: account,
              selected: widget.selectedAccountId == account.id,
              onSelect: () => widget.onSelectAccount(account),
              onEdit: () => widget.onEditAccount(account),
              onRemove: () => widget.onRemoveAccount(account),
              onToggle: () => widget.onToggleRegistration(account),
            ),
          ),
        ),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            icon: Icons.account_circle_outlined,
            title: tr('Accounts'),
            action: IconButton(
              tooltip: tr('Add account'),
              onPressed: widget.onAddAccount,
              icon: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 12),
          SearchBox(
            controller: _searchController,
            hintText: tr('Search accounts'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _PanelScrollableContent(
            enabled: widget.useInternalScroll,
            children: bodyChildren,
          ),
        ],
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: tr('Clear search'),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}

class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.account,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onRemove,
    required this.onToggle,
    super.key,
  });

  final WebRtcAccount account;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${account.username}@${account.domain}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                account.wssServer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (account.diagnostic != null) ...[
                const SizedBox(height: 10),
                RegistrationDiagnosticBanner(diagnostic: account.diagnostic!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onToggle,
                    icon: Icon(
                      account.status == RegistrationStatus.registered
                          ? Icons.logout
                          : Icons.login,
                    ),
                    label: Text(
                      account.status == RegistrationStatus.registered
                          ? tr('Disable')
                          : tr('Enable'),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('Edit account'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (account.diagnostic != null)
                    IconButton(
                      tooltip: tr('Registration details'),
                      onPressed: () =>
                          _showRegistrationDiagnosticDialog(context, account),
                      icon: const Icon(Icons.info_outline),
                    ),
                  IconButton(
                    tooltip: tr('Remove account'),
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegistrationDiagnosticBanner extends StatelessWidget {
  const RegistrationDiagnosticBanner({required this.diagnostic, super.key});

  final RegistrationDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final color = switch (diagnostic.severity) {
      RegistrationDiagnosticSeverity.info => Theme.of(
        context,
      ).colorScheme.primary,
      RegistrationDiagnosticSeverity.warning => const Color(0xFFB45309),
      RegistrationDiagnosticSeverity.error => const Color(0xFFB91C1C),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              diagnostic.retrying
                  ? Icons.sync_problem_outlined
                  : Icons.info_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                diagnostic.retrying
                    ? tr('{summary} · retrying', {
                        'summary': diagnostic.summary,
                      })
                    : diagnostic.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRegistrationDiagnosticDialog(
  BuildContext context,
  WebRtcAccount account,
) async {
  final diagnostic = account.diagnostic;
  if (diagnostic == null) return;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Registration diagnostic')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(label: tr('Account'), value: account.name),
              InfoRow(label: tr('SIP user'), value: account.username),
              InfoRow(label: tr('Domain'), value: account.domain),
              InfoRow(label: 'WSS', value: account.wssServer),
              InfoRow(label: tr('Status'), value: account.status.label),
              InfoRow(label: tr('Diagnostic'), value: diagnostic.summary),
              InfoRow(label: tr('Code'), value: diagnostic.code),
              if (diagnostic.reasonPhrase != null)
                InfoRow(label: tr('Reason'), value: diagnostic.reasonPhrase!),
              InfoRow(
                label: tr('Retrying'),
                value: diagnostic.retrying ? tr('Yes') : tr('No'),
              ),
              InfoRow(
                label: tr('Observed'),
                value: diagnostic.observedAt.toLocal().toString(),
              ),
              const SizedBox(height: 12),
              Text(
                diagnostic.localizedDetail,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: diagnostic.copyText));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(tr('Diagnostic copied'))));
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: Text(tr('Copy')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Close')),
        ),
      ],
    ),
  );
}

class DialerPanel extends StatelessWidget {
  const DialerPanel({
    required this.selectedAccount,
    required this.dialNumber,
    required this.voip,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    super.key,
  });

  final WebRtcAccount? selectedAccount;
  final String dialNumber;
  final PhoneWebVoipController voip;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final canCall =
        selectedAccount != null &&
        voip.registrationStatus == RegistrationStatus.registered &&
        dialNumber.trim().isNotEmpty &&
        !voip.hasActiveCall;
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(icon: Icons.dialpad_outlined, title: tr('Dialer')),
          const SizedBox(height: 16),
          AccountContextBanner(account: selectedAccount),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dialNumber.isEmpty
                                  ? tr('Enter number')
                                  : dialNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: dialNumber.isEmpty
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Backspace'),
                            onPressed: dialNumber.isEmpty ? null : onBackspace,
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                          IconButton(
                            tooltip: tr('Clear'),
                            onPressed: dialNumber.isEmpty ? null : onClear,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DialPad(onAppend: onAppend),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => onAppend('*97'),
                            child: const Icon(Icons.voicemail),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: canCall ? onCall : null,
                            icon: const Icon(Icons.call),
                            label: Text(tr('Call')),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (voip.hasActiveCall) ...[
                    const SizedBox(height: 14),
                    ActiveCallControls(voip: voip),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountContextBanner extends StatelessWidget {
  const AccountContextBanner({required this.account, super.key});

  final WebRtcAccount? account;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentAccount = account;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            account == null ? Icons.info_outline : Icons.router_outlined,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              currentAccount == null
                  ? tr('Select or add an account before placing calls.')
                  : '${currentAccount.name} · ${currentAccount.status.label}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class DialPad extends StatelessWidget {
  const DialPad({required this.onAppend, super.key});

  final ValueChanged<String> onAppend;

  @override
  Widget build(BuildContext context) {
    const values = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: values.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 58,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final value = values[index];

        return OutlinedButton(
          onPressed: () => onAppend(value),
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

class ActiveCallControls extends StatelessWidget {
  const ActiveCallControls({required this.voip, super.key});

  final PhoneWebVoipController voip;

  @override
  Widget build(BuildContext context) {
    final remote = voip.remoteIdentity.isEmpty
        ? tr('Unknown')
        : voip.remoteIdentity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.call_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$remote · ${voip.callState.name}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (voip.hasEstablishedCall) ...[
                const SizedBox(width: 10),
                Text(
                  voip.formattedCallDuration,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (voip.hasAnswerableIncomingCall) ...[
                FilledButton.icon(
                  onPressed: voip.answer,
                  icon: const Icon(Icons.call),
                  label: Text(tr('Answer')),
                ),
              ] else if (voip.hasPendingAnsweredIncomingCall) ...[
                FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: Text(tr('Connecting')),
                ),
              ] else ...[
                FilledButton.tonalIcon(
                  onPressed: voip.toggleMute,
                  icon: Icon(voip.muted ? Icons.mic_off : Icons.mic),
                  label: Text(voip.muted ? tr('Unmute') : tr('Mute')),
                ),
                FilledButton.tonalIcon(
                  onPressed: voip.holdSupported ? voip.toggleHold : null,
                  icon: Icon(voip.onHold ? Icons.play_arrow : Icons.pause),
                  label: Text(voip.onHold ? tr('Resume') : tr('Hold')),
                ),
              ],
              FilledButton.icon(
                onPressed: voip.rejectOrHangup,
                icon: const Icon(Icons.call_end),
                label: Text(
                  voip.hasAnswerableIncomingCall
                      ? tr('Decline')
                      : tr('Hang up'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CallHistoryPanel extends StatefulWidget {
  const CallHistoryPanel({
    required this.entries,
    this.contactForEntry,
    this.onDial,
    this.onAddContact,
    this.onRemove,
    this.onClearAll,
    this.useInternalScroll = false,
    super.key,
  });

  final List<PhoneCallHistoryEntry> entries;
  final PhoneContact? Function(PhoneCallHistoryEntry entry)? contactForEntry;
  final ValueChanged<PhoneCallHistoryEntry>? onDial;
  final ValueChanged<PhoneCallHistoryEntry>? onAddContact;
  final ValueChanged<PhoneCallHistoryEntry>? onRemove;
  final VoidCallback? onClearAll;
  final bool useInternalScroll;

  @override
  State<CallHistoryPanel> createState() => _CallHistoryPanelState();
}

class _CallHistoryPanelState extends State<CallHistoryPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = widget.entries
        .where(
          (entry) => _matchesCallHistoryEntry(entry, _searchController.text),
        )
        .toList();
    final bodyChildren = <Widget>[
      if (widget.entries.isEmpty)
        EmptyState(
          icon: Icons.call_outlined,
          title: tr('No calls yet'),
          message: tr('Completed calls will appear here.'),
        )
      else if (filteredEntries.isEmpty)
        EmptyState(
          icon: Icons.search_off_outlined,
          title: tr('No calls found'),
          message: tr('Search by number, account, status or SIP diagnostic.'),
        )
      else
        ...filteredEntries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CallHistoryTile(
              entry: entry,
              existingContact: widget.contactForEntry?.call(entry),
              onDial: widget.onDial == null
                  ? null
                  : () => widget.onDial!(entry),
              onAddContact: widget.onAddContact == null
                  ? null
                  : () => widget.onAddContact!(entry),
              onRemove: widget.onRemove == null
                  ? null
                  : () => widget.onRemove!(entry),
            ),
          ),
        ),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PanelTitle(
                  icon: Icons.history,
                  title: tr('Call history'),
                ),
              ),
              IconButton(
                onPressed: widget.entries.isEmpty ? null : widget.onClearAll,
                tooltip: tr('Clear all call history'),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchBox(
            controller: _searchController,
            hintText: tr('Search call history'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _PanelScrollableContent(
            enabled: widget.useInternalScroll,
            children: bodyChildren,
          ),
        ],
      ),
    );
  }
}

class CallHistoryTile extends StatelessWidget {
  const CallHistoryTile({
    required this.entry,
    this.existingContact,
    this.onDial,
    this.onAddContact,
    this.onRemove,
    super.key,
  });

  final PhoneCallHistoryEntry entry;
  final PhoneContact? existingContact;
  final VoidCallback? onDial;
  final VoidCallback? onAddContact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = switch (entry.direction) {
      PhoneCallDirection.incoming => Icons.call_received,
      PhoneCallDirection.outgoing => Icons.call_made,
    };
    final statusColor = switch (entry.status) {
      PhoneCallStatus.completed => colorScheme.primary,
      PhoneCallStatus.missed => Colors.orange,
      PhoneCallStatus.failed => colorScheme.error,
    };
    final statusLabel = switch (entry.status) {
      PhoneCallStatus.completed => tr('Completed'),
      PhoneCallStatus.missed => tr('Missed'),
      PhoneCallStatus.failed => tr('Failed'),
    };

    final summary =
        '$statusLabel · ${_formatCallDurationSeconds(entry.durationSeconds)}';
    final contact = existingContact;
    final hasContact = contact != null;
    final displayName = hasContact ? contact.name : entry.remoteIdentity;
    final fullNumber = _dialableHistoryIdentity(entry.remoteIdentity);

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withValues(alpha: 0.18),
              foregroundColor: statusColor,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fullNumber,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatShortTime(entry.startedAt),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 2,
                    runSpacing: 0,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: hasContact
                            ? tr('Already saved as contact')
                            : tr('Add to contacts'),
                        onPressed: hasContact ? null : onAddContact,
                        icon: Icon(
                          hasContact
                              ? Icons.how_to_reg_outlined
                              : Icons.person_add_alt_1_outlined,
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: tr('Remove from history'),
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: tr('Call back'),
                        onPressed: onDial,
                        icon: const Icon(Icons.call_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesPanel extends StatefulWidget {
  const MessagesPanel({this.useInternalScroll = false, super.key});

  final bool useInternalScroll;

  @override
  State<MessagesPanel> createState() => _MessagesPanelState();
}

class _MessagesPanelState extends State<MessagesPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(icon: Icons.chat_bubble_outline, title: tr('Messages')),
          const SizedBox(height: 12),
          SearchBox(
            controller: _searchController,
            hintText: tr('Search messages'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _PanelScrollableContent(
            enabled: widget.useInternalScroll,
            children: [
              EmptyState(
                icon: query.isEmpty
                    ? Icons.chat_bubble_outline
                    : Icons.search_off_outlined,
                title: query.isEmpty
                    ? tr('No messages yet')
                    : tr('No message found'),
                message: query.isEmpty
                    ? tr('Voicemail and messages will be available here.')
                    : tr(
                        'When messages are synced, the search will find them by contact, number, subject and content.',
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatCallDurationSeconds(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatShortTime(DateTime value) {
  final now = DateTime.now();
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return time;
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} $time';
}

String _dialableHistoryIdentity(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('sip:')) {
    final withoutScheme = trimmed.substring(4);
    return withoutScheme.split('@').first;
  }
  return trimmed.split('@').first;
}

String _normalizePhoneNumber(String value) {
  final dialable = _dialableHistoryIdentity(value);
  final digits = dialable.replaceAll(RegExp(r'\D'), '');
  if (digits.isNotEmpty) return digits;
  return dialable.trim().toLowerCase();
}

bool _matchesAccount(WebRtcAccount account, String query) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  return _searchableText([
    account.name,
    account.displayName,
    account.username,
    account.domain,
    account.wssServer,
    account.stunServer,
    account.turnServer,
    account.status.label,
    account.diagnostic?.summary,
    account.diagnostic?.detail,
    account.diagnostic?.code,
    account.diagnostic?.reasonPhrase,
  ]).contains(normalizedQuery);
}

bool _matchesContact(PhoneContact contact, String query) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  return _searchableText([
    contact.name,
    contact.number,
    contact.company,
    contact.source.name,
  ]).contains(normalizedQuery);
}

bool _matchesCallHistoryEntry(PhoneCallHistoryEntry entry, String query) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  final statusLabel = switch (entry.status) {
    PhoneCallStatus.completed => tr('Completed'),
    PhoneCallStatus.missed => tr('Missed'),
    PhoneCallStatus.failed => tr('Failed'),
  };
  final directionLabel = switch (entry.direction) {
    PhoneCallDirection.incoming => tr('Incoming'),
    PhoneCallDirection.outgoing => tr('Outgoing'),
  };

  return _searchableText([
    entry.remoteIdentity,
    _dialableHistoryIdentity(entry.remoteIdentity),
    entry.accountName,
    entry.diagnostic,
    statusLabel,
    directionLabel,
    _formatShortTime(entry.startedAt),
  ]).contains(normalizedQuery);
}

String _searchableText(Iterable<String?> values) {
  return values
      .whereType<String>()
      .map(_normalizeSearchText)
      .where((value) => value.isNotEmpty)
      .join(' ');
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}

class ContactsSummaryPanel extends StatefulWidget {
  const ContactsSummaryPanel({
    required this.contacts,
    required this.contactsSyncing,
    required this.onAddContact,
    required this.onSyncContacts,
    required this.onEditContact,
    required this.onDialContact,
    this.useInternalScroll = false,
    super.key,
  });

  final List<PhoneContact> contacts;
  final bool contactsSyncing;
  final VoidCallback onAddContact;
  final VoidCallback onSyncContacts;
  final ValueChanged<PhoneContact> onEditContact;
  final ValueChanged<PhoneContact> onDialContact;
  final bool useInternalScroll;

  @override
  State<ContactsSummaryPanel> createState() => _ContactsSummaryPanelState();
}

class _ContactsSummaryPanelState extends State<ContactsSummaryPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredContacts = widget.contacts
        .where((contact) => _matchesContact(contact, _searchController.text))
        .toList();
    final bodyChildren = <Widget>[
      if (widget.contacts.isEmpty)
        EmptyState(
          icon: Icons.contacts_outlined,
          title: tr('No contacts yet'),
          message: tr('Sync the device address book or add a local contact.'),
          actionLabel: tr('Sync contacts'),
          onAction: widget.contactsSyncing ? null : widget.onSyncContacts,
        )
      else if (filteredContacts.isEmpty)
        EmptyState(
          icon: Icons.search_off_outlined,
          title: tr('No contacts found'),
          message: tr('Search by name, company or number.'),
        )
      else
        ...filteredContacts.map(
          (contact) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(contact.name.isEmpty ? '?' : contact.name[0]),
            ),
            title: Text(
              contact.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              contact.number,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  onPressed: () => widget.onEditContact(contact),
                  tooltip: tr('Edit contact'),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => widget.onDialContact(contact),
                  tooltip: tr('Call contact'),
                  icon: const Icon(Icons.call_outlined),
                ),
              ],
            ),
          ),
        ),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PanelTitle(
                  icon: Icons.contacts_outlined,
                  title: tr('Contacts'),
                ),
              ),
              IconButton(
                onPressed: widget.contactsSyncing
                    ? null
                    : widget.onSyncContacts,
                tooltip: tr('Sync device contacts'),
                icon: widget.contactsSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
              ),
              IconButton(
                onPressed: widget.onAddContact,
                tooltip: tr('Add contact'),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SearchBox(
            controller: _searchController,
            hintText: tr('Search contacts'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _PanelScrollableContent(
            enabled: widget.useInternalScroll,
            children: bodyChildren,
          ),
        ],
      ),
    );
  }
}

class _PanelScrollableContent extends StatelessWidget {
  const _PanelScrollableContent({
    required this.enabled,
    required this.children,
  });

  final bool enabled;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return Expanded(
      child: Scrollbar(
        child: ListView(
          padding: EdgeInsets.zero,
          primary: false,
          children: children,
        ),
      ),
    );
  }
}

class ContactDialog extends StatefulWidget {
  const ContactDialog({
    this.contact,
    this.initialName = '',
    this.initialNumber = '',
    super.key,
  });

  final PhoneContact? contact;
  final String initialName;
  final String initialNumber;

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _companyController;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    _nameController = TextEditingController(
      text: contact?.name ?? widget.initialName,
    );
    _numberController = TextEditingController(
      text: contact?.number ?? widget.initialNumber,
    );
    _companyController = TextEditingController(text: contact?.company ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact == null
                      ? tr('Add contact')
                      : tr('Edit contact'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: tr('Name')),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numberController,
                  decoration: InputDecoration(labelText: tr('Phone number')),
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(labelText: tr('Company')),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('Cancel')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: Text(tr('Save'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? tr('Required field') : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.contact;
    Navigator.pop(
      context,
      PhoneContact(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        number: _numberController.text.trim(),
        company: _companyController.text.trim(),
        source: existing?.source ?? PhoneContactSource.manual,
      ),
    );
  }
}

class AccountDialog extends StatefulWidget {
  const AccountDialog({this.account, super.key});

  final WebRtcAccount? account;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _domainController;
  late final TextEditingController _wssController;
  late final TextEditingController _stunController;
  late final TextEditingController _turnController;
  late final TextEditingController _passwordController;
  WebRtcCodecPolicy _codecPolicy = WebRtcCodecPolicy.automaticRecommended;
  bool _enabled = true;
  bool _autoRegister = true;
  bool _allowInsecureTransport = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;

    _nameController = TextEditingController(text: account?.name ?? '');
    _displayNameController = TextEditingController(
      text: account?.displayName ?? '',
    );
    _usernameController = TextEditingController(text: account?.username ?? '');
    _domainController = TextEditingController(text: account?.domain ?? '');
    _wssController = TextEditingController(text: account?.wssServer ?? '');
    _stunController = TextEditingController(text: account?.stunServer ?? '');
    _turnController = TextEditingController(text: account?.turnServer ?? '');
    _passwordController = TextEditingController(text: account?.password ?? '');
    _codecPolicy =
        account?.codecPolicy ?? WebRtcCodecPolicy.automaticRecommended;
    _enabled = account?.enabled ?? true;
    _autoRegister = account?.autoRegister ?? true;
    _allowInsecureTransport = account?.allowInsecureTransport ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _domainController.dispose();
    _wssController.dispose();
    _stunController.dispose();
    _turnController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 16 : 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.account == null
                        ? tr('Add WebRTC account')
                        : tr('Edit WebRTC account'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: tr('Account name'),
                          ),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: tr('Display name'),
                          ),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: tr('SIP user'),
                          ),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: tr('SIP Password'),
                          ),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _domainController,
                          decoration: InputDecoration(
                            labelText: tr('SIP Domain'),
                          ),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _wssController,
                          decoration: InputDecoration(
                            labelText: tr('WSS server'),
                            hintText: 'wss://pbx.example.com/ws',
                          ),
                          validator: _wss,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _stunController,
                          decoration: InputDecoration(
                            labelText: tr('STUN server'),
                            hintText: 'stun:stun.example.com:3478',
                          ),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _turnController,
                          decoration: InputDecoration(
                            labelText: tr('TURN server'),
                            hintText: 'turn:turn.example.com:3478',
                          ),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: DropdownButtonFormField<WebRtcCodecPolicy>(
                          initialValue: _codecPolicy,
                          decoration: InputDecoration(
                            labelText: tr('Codec policy'),
                          ),
                          items: WebRtcCodecPolicy.values
                              .map(
                                (policy) => DropdownMenuItem<WebRtcCodecPolicy>(
                                  value: policy,
                                  child: Text(policy.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _codecPolicy = value;
                            });
                          },
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 464,
                        child: Text(
                          _codecPolicy.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: _enabled,
                        label: Text(tr('Enabled')),
                        avatar: Icon(_enabled ? Icons.check : Icons.close),
                        onSelected: (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                      ),
                      FilterChip(
                        selected: _autoRegister,
                        label: Text(tr('Auto register')),
                        avatar: Icon(
                          _autoRegister ? Icons.sync : Icons.sync_disabled,
                        ),
                        onSelected: (value) {
                          setState(() {
                            _autoRegister = value;
                          });
                        },
                      ),
                      FilterChip(
                        selected: _allowInsecureTransport,
                        label: Text(tr('Allow WS dev')),
                        avatar: Icon(
                          _allowInsecureTransport
                              ? Icons.lock_open
                              : Icons.lock_outline,
                        ),
                        onSelected: (value) {
                          setState(() {
                            _allowInsecureTransport = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tr('Cancel')),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(tr('Save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('Required');
    }
    return null;
  }

  String? _wss(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    final trimmed = value!.trim();
    if (!trimmed.startsWith('wss://') && !trimmed.startsWith('ws://')) {
      return tr('Use a WSS URL');
    }
    if (trimmed.startsWith('ws://') && !_allowInsecureTransport) {
      return tr('Enable WS dev for insecure transport');
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.account;
    final account = WebRtcAccount(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      displayName: _displayNameController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      domain: _domainController.text.trim(),
      wssServer: _wssController.text.trim(),
      stunServer: _stunController.text.trim(),
      turnServer: _turnController.text.trim(),
      hasPassword:
          _passwordController.text.isNotEmpty ||
          (existing?.hasPassword ?? false),
      allowInsecureTransport: _allowInsecureTransport,
      codecPolicy: _codecPolicy,
      enabled: _enabled,
      autoRegister: _autoRegister,
      status: existing?.status ?? RegistrationStatus.offline,
      diagnostic: existing?.diagnostic,
    );

    Navigator.of(context).pop(account);
  }
}

class DialogField extends StatelessWidget {
  const DialogField({required this.width, required this.child, super.key});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class PanelTitle extends StatelessWidget {
  const PanelTitle({
    required this.icon,
    required this.title,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?action,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RegistrationStatus.registered => const Color(0xFF047857),
      RegistrationStatus.registering => const Color(0xFFB45309),
      RegistrationStatus.failed => const Color(0xFFB91C1C),
      RegistrationStatus.offline => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      label: Text(status.label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
