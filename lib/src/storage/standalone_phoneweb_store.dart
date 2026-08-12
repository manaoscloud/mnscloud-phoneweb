import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../account/webrtc_account.dart';
import '../contacts/phone_contact.dart';

class StandalonePhoneWebStore {
  static const _accountsKey = 'mnscloud_phoneweb.accounts.v1';
  static const _contactsKey = 'mnscloud_phoneweb.contacts.v1';
  static const _historyKey = 'mnscloud_phoneweb.call_history.v1';
  static const _selectedAccountKey = 'mnscloud_phoneweb.selected_account.v1';
  static const _maxHistoryItems = 250;

  Future<StandalonePhoneWebState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StandalonePhoneWebState(
      accounts: _decodeList(
        prefs.getString(_accountsKey),
        WebRtcAccount.fromJson,
      ),
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
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
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
