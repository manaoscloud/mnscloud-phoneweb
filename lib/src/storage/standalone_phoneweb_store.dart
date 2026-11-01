import 'dart:convert';

import '../account/webrtc_account.dart';
import '../contacts/phone_contact.dart';
import 'account_secret_store.dart';
import 'account_secret_sync.dart';
import 'local_data_vault.dart';

/// Accounts, manual contacts, call history and the selected account of the
/// standalone phone, encrypted at rest on every target ([LocalDataVault],
/// `docs/security.md`). SIP passwords stay apart in [AccountSecretStore].
///
/// Records of older releases are in clear: [load] reads them, writes the
/// encrypted copy and only then removes them. When nothing can be encrypted
/// (no WebCrypto or secure storage), changes stay in memory instead of being
/// written in clear.
class StandalonePhoneWebStore {
  StandalonePhoneWebStore({AccountSecretStore? secrets, LocalDataVault? vault})
    : _secrets = AccountSecretSync(secrets ?? AccountSecretStore()),
      _vault = vault ?? LocalDataVault();

  final AccountSecretSync _secrets;
  final LocalDataVault _vault;
  static const _accounts = 'accounts';
  static const _contacts = 'contacts';
  static const _history = 'call_history';
  static const _selectedAccount = 'selected_account';
  static const _maxHistoryItems = 250;

  Future<StandalonePhoneWebState> load() async {
    final storedAccounts = await _vault.read(_accounts);
    final legacyAccounts = storedAccounts == null
        ? await _vault.readLegacy(_accounts)
        : null;
    final hydrated = await _secrets.hydrate(
      _decodeList(storedAccounts ?? legacyAccounts, WebRtcAccount.fromJson),
    );
    if (legacyAccounts != null) {
      if (await _writeAccounts(hydrated.accounts)) {
        await _vault.removeLegacy(_accounts);
      } else if (hydrated.migrated) {
        // Not encrypted, but at least without the passwords now in the secret store.
        await _vault.writeLegacy(_accounts, _encodeAccounts(hydrated.accounts));
      }
    } else if (hydrated.migrated) {
      await _writeAccounts(hydrated.accounts);
    }
    return StandalonePhoneWebState(
      accounts: hydrated.accounts,
      contacts: _decodeList(await _restore(_contacts), PhoneContact.fromJson),
      callHistory: _decodeList(
        await _restore(_history),
        PhoneCallHistoryEntry.fromJson,
      ),
      selectedAccountId: await _restore(_selectedAccount),
    );
  }

  Future<void> saveAccounts(
    List<WebRtcAccount> accounts, {
    String? selectedAccountId,
  }) async {
    final previousIds = _decodeList(
      await _vault.read(_accounts) ?? await _vault.readLegacy(_accounts),
      WebRtcAccount.fromJson,
    ).map((account) => account.id).toList();
    await _writeAccounts(accounts);
    await _secrets.save(accounts, previousIds: previousIds);
    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      await _vault.remove(_selectedAccount);
      await _vault.removeLegacy(_selectedAccount);
    } else {
      await _save(_selectedAccount, selectedAccountId);
    }
  }

  Future<void> saveContacts(List<PhoneContact> contacts) {
    final manualContacts = contacts
        .where((contact) => contact.source == PhoneContactSource.manual)
        .map((contact) => contact.toJson())
        .toList();
    return _save(_contacts, jsonEncode(manualContacts));
  }

  Future<void> saveCallHistory(List<PhoneCallHistoryEntry> entries) {
    final limited = entries.take(_maxHistoryItems).toList();
    return _save(
      _history,
      jsonEncode(limited.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<bool> _writeAccounts(List<WebRtcAccount> accounts) =>
      _save(_accounts, _encodeAccounts(accounts));

  String _encodeAccounts(List<WebRtcAccount> accounts) =>
      jsonEncode(accounts.map((account) => account.toJson()).toList());

  /// Writes the encrypted copy; the clear record of an older release goes only
  /// after that succeeds.
  Future<bool> _save(String name, String value) async {
    if (!await _vault.write(name, value)) return false;
    await _vault.removeLegacy(name);
    return true;
  }

  Future<String?> _restore(String name) async {
    final stored = await _vault.read(name);
    if (stored != null) return stored;
    final legacy = await _vault.readLegacy(name);
    if (legacy != null) await _save(name, legacy);
    return legacy;
  }

  List<T> _decodeList<T>(
    String? encoded,
    T Function(Map<String, dynamic> json) decoder,
  ) {
    if (encoded == null || encoded.trim().isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <T>[];
      return decoded
          .whereType<Map>()
          .map((item) => decoder(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return <T>[];
    }
  }
}

class StandalonePhoneWebState {
  const StandalonePhoneWebState({
    required this.accounts,
    required this.contacts,
    required this.callHistory,
    this.selectedAccountId,
  });

  final List<WebRtcAccount> accounts;
  final List<PhoneContact> contacts;
  final List<PhoneCallHistoryEntry> callHistory;
  final String? selectedAccountId;
}
