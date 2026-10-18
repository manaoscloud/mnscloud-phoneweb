import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../account/webrtc_account.dart';
import '../contacts/phone_contact.dart';
import 'account_secret_store.dart';
import 'account_secret_sync.dart';

class StandalonePhoneWebStore {
  StandalonePhoneWebStore({AccountSecretStore? secrets})
    : _secrets = AccountSecretSync(secrets ?? AccountSecretStore());

  final AccountSecretSync _secrets;
  static const _accountsKey = 'mnscloud_phoneweb.accounts.v1';
  static const _contactsKey = 'mnscloud_phoneweb.contacts.v1';
  static const _historyKey = 'mnscloud_phoneweb.call_history.v1';
  static const _selectedAccountKey = 'mnscloud_phoneweb.selected_account.v1';
  static const _maxHistoryItems = 250;

  Future<StandalonePhoneWebState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final hydrated = await _secrets.hydrate(
      _decodeList(prefs.getString(_accountsKey), WebRtcAccount.fromJson),
    );
    if (hydrated.migrated) {
      await _writeAccountsMetadata(prefs, hydrated.accounts);
    }
    return StandalonePhoneWebState(
      accounts: hydrated.accounts,
      contacts: _decodeList(
        prefs.getString(_contactsKey),
        PhoneContact.fromJson,
      ),
      callHistory: _decodeList(
        prefs.getString(_historyKey),
        PhoneCallHistoryEntry.fromJson,
      ),
      selectedAccountId: prefs.getString(_selectedAccountKey),
    );
  }

  Future<void> saveAccounts(
    List<WebRtcAccount> accounts, {
    String? selectedAccountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previousIds = _decodeList(
      prefs.getString(_accountsKey),
      WebRtcAccount.fromJson,
    ).map((account) => account.id).toList();
    await _writeAccountsMetadata(prefs, accounts);
    await _secrets.save(accounts, previousIds: previousIds);
    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      await prefs.remove(_selectedAccountKey);
    } else {
      await prefs.setString(_selectedAccountKey, selectedAccountId);
    }
  }

  Future<void> saveContacts(List<PhoneContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final manualContacts = contacts
        .where((contact) => contact.source == PhoneContactSource.manual)
        .map((contact) => contact.toJson())
        .toList();
    await prefs.setString(_contactsKey, jsonEncode(manualContacts));
  }

  Future<void> saveCallHistory(List<PhoneCallHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final limited = entries.take(_maxHistoryItems).toList();
    await prefs.setString(
      _historyKey,
      jsonEncode(limited.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _writeAccountsMetadata(
    SharedPreferences prefs,
    List<WebRtcAccount> accounts,
  ) {
    return prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
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
