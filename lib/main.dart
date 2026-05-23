import 'package:flutter/material.dart';

import 'src/account/webrtc_account.dart';
import 'src/voip/phoneweb_voip_controller.dart';

void main() {
  runApp(const PhoneWebApp());
}

class PhoneWebApp extends StatelessWidget {
  const PhoneWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNSCloud PhoneWeb',
      debugShowCheckedModeBanner: false,
      theme: _phoneWebTheme(Brightness.light),
      darkTheme: _phoneWebTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const PhoneWebHomePage(),
    );
  }
}

ThemeData _phoneWebTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF151515) : const Color(0xFFF7F8F5),
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
  late final PhoneWebVoipController _voip;
  String? _selectedAccountId;
  String _dialNumber = '';
  String _lastEvent = 'Ready';
  int _mobileTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _voip = PhoneWebVoipController();
    _voip.addListener(_syncVoipState);
  }

  @override
  void dispose() {
    _voip.removeListener(_syncVoipState);
    _voip.dispose();
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

  Future<void> _openAccountDialog({WebRtcAccount? account}) async {
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
        _lastEvent = '${result.name} updated';
      } else {
        _accounts.add(result);
        _selectedAccountId = result.id;
        _lastEvent = '${result.name} added';
      }
    });

    if (result.autoRegister && result.enabled) {
      await _voip.register(result);
    }
  }

  void _removeAccount(WebRtcAccount account) {
    setState(() {
      _accounts.removeWhere((item) => item.id == account.id);
      if (_selectedAccountId == account.id) {
        _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;
      }
      _lastEvent = '${account.name} removed';
    });
  }

  Future<void> _toggleRegistration(WebRtcAccount account) async {
    if (account.status == RegistrationStatus.registered ||
        account.status == RegistrationStatus.registering) {
      await _voip.unregister();
      return;
    }

    await _voip.register(account);
  }

  void _syncVoipState() {
    setState(() {
      final activeAccount = _voip.account;
      if (activeAccount != null) {
        final index =
            _accounts.indexWhere((item) => item.id == activeAccount.id);
        if (index >= 0) {
          _accounts[index] = _accounts[index].copyWith(
            status: _voip.registrationStatus,
            enabled: _voip.registrationStatus == RegistrationStatus.registered,
          );
        }
      }
      _lastEvent = _voip.lastEvent;
    });
  }

  void _appendDial(String value) {
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

  Future<void> _openContactDialog({PhoneContact? contact}) async {
    final result = await showDialog<PhoneContact>(
      context: context,
      builder: (context) => ContactDialog(contact: contact),
    );
    if (result == null) return;

    setState(() {
      final index = _contacts.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _contacts[index] = result;
      } else {
        _contacts.add(result);
      }
      _lastEvent = '${result.name} saved';
    });
  }

  void _dialContact(PhoneContact contact) {
    setState(() {
      _dialNumber = contact.number;
      _mobileTabIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 640) {
      return MobilePhoneShell(
        accounts: _accounts,
        contacts: _contacts,
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
        onAddAccount: () => _openAccountDialog(),
        onEditAccount: (account) => _openAccountDialog(account: account),
        onRemoveAccount: _removeAccount,
        onSelectAccount: (account) {
          setState(() {
            _selectedAccountId = account.id;
          });
        },
        onToggleRegistration: _toggleRegistration,
        onAddContact: () => _openContactDialog(),
        onEditContact: (contact) => _openContactDialog(contact: contact),
        onDialContact: _dialContact,
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
                onAddAccount: () => _openAccountDialog(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: compact
                    ? ListView(
                        children: _buildPanels(compact: true),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 360,
                            child: AccountPanel(
                              accounts: _accounts,
                              selectedAccountId: _selectedAccount?.id,
                              onAddAccount: () => _openAccountDialog(),
                              onEditAccount: (account) =>
                                  _openAccountDialog(account: account),
                              onRemoveAccount: _removeAccount,
                              onSelectAccount: (account) {
                                setState(() {
                                  _selectedAccountId = account.id;
                                });
                              },
                              onToggleRegistration: _toggleRegistration,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: WorkspacePanels(
                              selectedAccount: _selectedAccount,
                              dialNumber: _dialNumber,
                              voip: _voip,
                              accountCount: _accounts.length,
                              lastEvent: _lastEvent,
                              onAppend: _appendDial,
                              onBackspace: _backspaceDial,
                              onClear: _clearDial,
                              onCall: _makeCall,
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
        },
        onToggleRegistration: _toggleRegistration,
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
      BottomPanels(
        accountCount: _accounts.length,
        voip: _voip,
        lastEvent: _lastEvent,
      ),
    ];
  }
}

class WorkspacePanels extends StatelessWidget {
  const WorkspacePanels({
    required this.selectedAccount,
    required this.dialNumber,
    required this.voip,
    required this.accountCount,
    required this.lastEvent,
    required this.onAppend,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
    super.key,
  });

  final WebRtcAccount? selectedAccount;
  final String dialNumber;
  final PhoneWebVoipController voip;
  final int accountCount;
  final String lastEvent;
  final ValueChanged<String> onAppend;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;

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
                    DiagnosticsPanel(
                      accountCount: accountCount,
                      voip: voip,
                      lastEvent: lastEvent,
                    ),
                    const SizedBox(height: 16),
                    const Expanded(child: CallHistoryPanel()),
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
            BottomPanels(
              accountCount: accountCount,
              voip: voip,
              lastEvent: lastEvent,
            ),
          ],
        );
      },
    );
  }
}

class PhoneContact {
  PhoneContact({
    required this.id,
    required this.name,
    required this.number,
    this.company = '',
  });

  final String id;
  final String name;
  final String number;
  final String company;
}

class MobilePhoneShell extends StatelessWidget {
  const MobilePhoneShell({
    required this.accounts,
    required this.contacts,
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
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onRemoveAccount,
    required this.onSelectAccount,
    required this.onToggleRegistration,
    required this.onAddContact,
    required this.onEditContact,
    required this.onDialContact,
    super.key,
  });

  final List<WebRtcAccount> accounts;
  final List<PhoneContact> contacts;
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
  final VoidCallback onAddAccount;
  final ValueChanged<WebRtcAccount> onEditAccount;
  final ValueChanged<WebRtcAccount> onRemoveAccount;
  final ValueChanged<WebRtcAccount> onSelectAccount;
  final ValueChanged<WebRtcAccount> onToggleRegistration;
  final VoidCallback onAddContact;
  final ValueChanged<PhoneContact> onEditContact;
  final ValueChanged<PhoneContact> onDialContact;

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
      ),
      const MobileHistoryView(),
      const MobileMessagesView(),
    ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            MobileTopBar(
              account: selectedAccount,
              accountCount: accounts.length,
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dialpad),
              label: 'Telefone',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Contatos',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Historico',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Mensagens',
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
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Accounts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onAddAccount();
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: Text('No WebRTC accounts')),
                  )
                else
                  ...accounts.map(
                    (account) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(account.name),
                      subtitle: Text('${account.username}@${account.domain}'),
                      leading: Icon(
                        selectedAccount?.id == account.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            onPressed: () => onToggleRegistration(account),
                            icon: Icon(
                              account.status == RegistrationStatus.registered
                                  ? Icons.logout
                                  : Icons.login,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onEditAccount(account);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      onTap: () {
                        onSelectAccount(account);
                        Navigator.pop(context);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MobileTopBar extends StatelessWidget {
  const MobileTopBar({
    required this.account,
    required this.accountCount,
    required this.onAccounts,
    super.key,
  });

  final WebRtcAccount? account;
  final int accountCount;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    final currentAccount = account;
    final registered = currentAccount?.status == RegistrationStatus.registered;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 118,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _timeLabel(TimeOfDay.now()),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.person, size: 20),
              const Spacer(),
              const Icon(Icons.signal_cellular_alt, size: 22),
              const SizedBox(width: 10),
              const Icon(Icons.wifi, size: 24),
              const SizedBox(width: 10),
              const Icon(Icons.battery_6_bar, size: 28),
            ],
          ),
          const Spacer(),
          Row(
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
              Expanded(
                child: Column(
                  children: [
                    Text(
                      registered ? 'Registrado' : 'Sem Servico',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      currentAccount == null
                          ? 'Vazio'
                          : '${currentAccount.username}@${currentAccount.domain}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  static String _timeLabel(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
    final canCall = selectedAccount != null &&
        voip.registrationStatus == RegistrationStatus.registered &&
        dialNumber.trim().isNotEmpty &&
        !voip.hasActiveCall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tightHeight = constraints.maxHeight < 480;
        final compactHeight = constraints.maxHeight < 560;
        final dialKeyHeight = tightHeight
            ? 56.0
            : compactHeight
                ? 68.0
                : 86.0;
        final callButtonSize = tightHeight
            ? 54.0
            : compactHeight
                ? 60.0
                : 74.0;
        final brandIconSize = tightHeight
            ? 48.0
            : compactHeight
                ? 72.0
                : 104.0;
        final brandFontSize = tightHeight
            ? 24.0
            : compactHeight
                ? 32.0
                : 42.0;
        final numberFontSize = tightHeight
            ? 30.0
            : compactHeight
                ? 34.0
                : 42.0;
        final contentPadding = tightHeight
            ? 6.0
            : compactHeight
                ? 12.0
                : 24.0;

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
                                      ? 6
                                      : compactHeight
                                          ? 8
                                          : 18),
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
                            dialNumber,
                            key: const ValueKey('number'),
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
                    ? 4
                    : compactHeight
                        ? 8
                        : 22,
                8,
                4,
              ),
              child: MobileDialPad(
                keyHeight: dialKeyHeight,
                onAppend: onAppend,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                26,
                0,
                26,
                tightHeight
                    ? 6
                    : compactHeight
                        ? 8
                        : 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MobileUtilityButton(
                      icon: Icons.voicemail,
                      label: 'VM',
                      compact: compactHeight,
                      onPressed: () => onAppend('*97'),
                    ),
                  ),
                  SizedBox(
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
                      child: Icon(Icons.call, size: compactHeight ? 28 : 34),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: dialNumber.isEmpty ? null : onBackspace,
                        icon: Icon(
                          Icons.backspace_outlined,
                          size: compactHeight ? 28 : 34,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (voip.hasActiveCall)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: ActiveCallControls(voip: voip),
              ),
          ],
        );
      },
    );
  }
}

class MobileDialPad extends StatelessWidget {
  const MobileDialPad({
    required this.onAppend,
    this.keyHeight = 86,
    super.key,
  });

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
            shape: const RoundedRectangleBorder(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                key.$1,
                style: TextStyle(
                  fontSize: keyHeight < 76 ? 34 : 40,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
              ),
              SizedBox(
                height: 20,
                child: Text(
                  key.$2,
                  style: TextStyle(
                    fontSize: 13,
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
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 28 : 34, color: colorScheme.onSurface),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class MobileContactsView extends StatelessWidget {
  const MobileContactsView({
    required this.contacts,
    required this.onAddContact,
    required this.onEditContact,
    required this.onDialContact,
    super.key,
  });

  final List<PhoneContact> contacts;
  final VoidCallback onAddContact;
  final ValueChanged<PhoneContact> onEditContact;
  final ValueChanged<PhoneContact> onDialContact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Contatos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onAddContact,
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar contato',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: contacts.isEmpty
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
                        const Text('Nenhum contato'),
                        const SizedBox(height: 4),
                        Text(
                          'Adicione contatos para discar mais rapido.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: onAddContact,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar contato'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: colorScheme.outlineVariant),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          child: Text(
                              contact.name.isEmpty ? '?' : contact.name[0]),
                        ),
                        title: Text(contact.name),
                        subtitle: Text(
                          contact.company.isEmpty
                              ? contact.number
                              : '${contact.company} · ${contact.number}',
                        ),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              onPressed: () => onEditContact(contact),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: () => onDialContact(contact),
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

class MobileHistoryView extends StatelessWidget {
  const MobileHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileEmptyTab(
      icon: Icons.history,
      title: 'Historico vazio',
      message: 'As chamadas realizadas e recebidas aparecerao aqui.',
    );
  }
}

class MobileMessagesView extends StatelessWidget {
  const MobileMessagesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MobileEmptyTab(
      icon: Icons.chat_bubble_outline,
      title: 'Mensagens',
      message: 'Correio de voz e mensagens ficarao disponiveis aqui.',
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
    required this.onAddAccount,
    super.key,
  });

  final int accountCount;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Flex(
      direction: compact ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MNSCloud PhoneWeb',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$accountCount WebRTC account${accountCount == 1 ? '' : 's'} configured',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        SizedBox(
            height: compact ? 14 : 0, width: compact ? double.infinity : 0),
        FilledButton.icon(
          onPressed: onAddAccount,
          icon: const Icon(Icons.add),
          label: const Text('Add account'),
        ),
      ],
    );
  }
}

class AccountPanel extends StatelessWidget {
  const AccountPanel({
    required this.accounts,
    required this.selectedAccountId,
    required this.onAddAccount,
    required this.onEditAccount,
    required this.onRemoveAccount,
    required this.onSelectAccount,
    required this.onToggleRegistration,
    super.key,
  });

  final List<WebRtcAccount> accounts;
  final String? selectedAccountId;
  final VoidCallback onAddAccount;
  final ValueChanged<WebRtcAccount> onEditAccount;
  final ValueChanged<WebRtcAccount> onRemoveAccount;
  final ValueChanged<WebRtcAccount> onSelectAccount;
  final ValueChanged<WebRtcAccount> onToggleRegistration;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            icon: Icons.account_circle_outlined,
            title: 'Accounts',
            action: IconButton(
              tooltip: 'Add account',
              onPressed: onAddAccount,
              icon: const Icon(Icons.add),
            ),
          ),
          const SizedBox(height: 12),
          if (accounts.isEmpty)
            EmptyState(
              icon: Icons.wifi_calling_3_outlined,
              title: 'No WebRTC accounts',
              message: 'Add a WSS provider account to start configuring calls.',
              actionLabel: 'Add account',
              onAction: onAddAccount,
            )
          else
            ...accounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AccountTile(
                  account: account,
                  selected: selectedAccountId == account.id,
                  onSelect: () => onSelectAccount(account),
                  onEdit: () => onEditAccount(account),
                  onRemove: () => onRemoveAccount(account),
                  onToggle: () => onToggleRegistration(account),
                ),
              ),
            ),
        ],
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${account.username}@${account.domain}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: account.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                account.wssServer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                          ? 'Disable'
                          : 'Enable',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit account',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove account',
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
    final canCall = selectedAccount != null &&
        voip.registrationStatus == RegistrationStatus.registered &&
        dialNumber.trim().isNotEmpty &&
        !voip.hasActiveCall;
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(
            icon: Icons.dialpad_outlined,
            title: 'Dialer',
          ),
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
                              dialNumber.isEmpty ? 'Enter number' : dialNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: dialNumber.isEmpty
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Backspace',
                            onPressed: dialNumber.isEmpty ? null : onBackspace,
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                          IconButton(
                            tooltip: 'Clear',
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: canCall ? onCall : null,
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                    ),
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
                  ? 'Select or add an account before placing calls.'
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
    final remote =
        voip.remoteIdentity.isEmpty ? 'Unknown' : voip.remoteIdentity;

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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (voip.hasIncomingCall)
                FilledButton.icon(
                  onPressed: voip.answer,
                  icon: const Icon(Icons.call),
                  label: const Text('Answer'),
                ),
              FilledButton.tonalIcon(
                onPressed: voip.toggleMute,
                icon: Icon(voip.muted ? Icons.mic_off : Icons.mic),
                label: Text(voip.muted ? 'Unmute' : 'Mute'),
              ),
              FilledButton.tonalIcon(
                onPressed: voip.toggleHold,
                icon: Icon(voip.onHold ? Icons.play_arrow : Icons.pause),
                label: Text(voip.onHold ? 'Resume' : 'Hold'),
              ),
              FilledButton.icon(
                onPressed: voip.rejectOrHangup,
                icon: const Icon(Icons.call_end),
                label: const Text('Hang up'),
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

class BottomPanels extends StatelessWidget {
  const BottomPanels({
    required this.accountCount,
    required this.voip,
    required this.lastEvent,
    super.key,
  });

  final int accountCount;
  final PhoneWebVoipController voip;
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final panels = [
      Expanded(
        child: DiagnosticsPanel(
          accountCount: accountCount,
          voip: voip,
          lastEvent: lastEvent,
        ),
      ),
      const SizedBox(width: 16, height: 16),
      const Expanded(child: CallHistoryPanel()),
    ];

    if (compact) {
      return Column(
        children: [
          DiagnosticsPanel(
            accountCount: accountCount,
            voip: voip,
            lastEvent: lastEvent,
          ),
          const SizedBox(height: 16),
          const CallHistoryPanel(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: panels,
    );
  }
}

class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({
    required this.accountCount,
    required this.voip,
    required this.lastEvent,
    super.key,
  });

  final int accountCount;
  final PhoneWebVoipController voip;
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(
            icon: Icons.monitor_heart_outlined,
            title: 'Diagnostics',
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'WebRTC engine', value: 'sip_ua'),
          InfoRow(label: 'Transport', value: voip.transportState.name),
          InfoRow(label: 'Registration', value: voip.registrationStatus.label),
          InfoRow(label: 'Call state', value: voip.callState.name),
          InfoRow(label: 'Accounts loaded', value: '$accountCount'),
          InfoRow(label: 'Last event', value: lastEvent),
        ],
      ),
    );
  }
}

class CallHistoryPanel extends StatelessWidget {
  const CallHistoryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(
            icon: Icons.history,
            title: 'Call history',
          ),
          SizedBox(height: 12),
          EmptyState(
            icon: Icons.call_outlined,
            title: 'No calls yet',
            message: 'Completed calls will appear here.',
          ),
        ],
      ),
    );
  }
}

class ContactDialog extends StatefulWidget {
  const ContactDialog({this.contact, super.key});

  final PhoneContact? contact;

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
    _nameController = TextEditingController(text: contact?.name ?? '');
    _numberController = TextEditingController(text: contact?.number ?? '');
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
                  widget.contact == null ? 'Add contact' : 'Edit contact',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _numberController,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  keyboardType: TextInputType.phone,
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
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
    return value == null || value.trim().isEmpty ? 'Required field' : null;
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
  bool _enabled = true;
  bool _autoRegister = true;
  bool _allowInsecureTransport = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;

    _nameController = TextEditingController(text: account?.name ?? '');
    _displayNameController =
        TextEditingController(text: account?.displayName ?? '');
    _usernameController = TextEditingController(text: account?.username ?? '');
    _domainController = TextEditingController(text: account?.domain ?? '');
    _wssController = TextEditingController(text: account?.wssServer ?? '');
    _stunController = TextEditingController(text: account?.stunServer ?? '');
    _turnController = TextEditingController(text: account?.turnServer ?? '');
    _passwordController = TextEditingController(text: account?.password ?? '');
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
                        ? 'Add WebRTC account'
                        : 'Edit WebRTC account',
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
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: 'Account name'),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _displayNameController,
                          decoration:
                              const InputDecoration(labelText: 'Display name'),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _usernameController,
                          decoration:
                              const InputDecoration(labelText: 'SIP user'),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _domainController,
                          decoration:
                              const InputDecoration(labelText: 'Domain'),
                          validator: _required,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 224,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                        ),
                      ),
                      DialogField(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _wssController,
                          decoration: const InputDecoration(
                            labelText: 'WSS server',
                            hintText: 'wss://pbx.example.com/ws',
                          ),
                          validator: _wss,
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _stunController,
                          decoration: const InputDecoration(
                            labelText: 'STUN server',
                            hintText: 'stun:stun.example.com:3478',
                          ),
                        ),
                      ),
                      DialogField(
                        width: compact ? double.infinity : 348,
                        child: TextFormField(
                          controller: _turnController,
                          decoration: const InputDecoration(
                            labelText: 'TURN server',
                            hintText: 'turn:turn.example.com:3478',
                          ),
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
                        label: const Text('Enabled'),
                        avatar: Icon(_enabled ? Icons.check : Icons.close),
                        onSelected: (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                      ),
                      FilterChip(
                        selected: _autoRegister,
                        label: const Text('Auto register'),
                        avatar: Icon(
                            _autoRegister ? Icons.sync : Icons.sync_disabled),
                        onSelected: (value) {
                          setState(() {
                            _autoRegister = value;
                          });
                        },
                      ),
                      FilterChip(
                        selected: _allowInsecureTransport,
                        label: const Text('Allow WS dev'),
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
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
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
      return 'Required';
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
      return 'Use a WSS URL';
    }
    if (trimmed.startsWith('ws://') && !_allowInsecureTransport) {
      return 'Enable WS dev for insecure transport';
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
      hasPassword: _passwordController.text.isNotEmpty ||
          (existing?.hasPassword ?? false),
      allowInsecureTransport: _allowInsecureTransport,
      enabled: _enabled,
      autoRegister: _autoRegister,
      status: existing?.status ?? RegistrationStatus.offline,
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (action != null) action!,
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
          Icon(
            icon,
            size: 34,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
      RegistrationStatus.offline =>
        Theme.of(context).colorScheme.onSurfaceVariant,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
