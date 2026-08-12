import 'dart:convert';

import 'package:web/web.dart' as web;

import '../account/webrtc_account.dart';
import '../contacts/phone_contact.dart';
import 'standalone_phoneweb_store_shared_preferences.dart'
    show StandalonePhoneWebState;

class StandalonePhoneWebStore {
  static const _accountsKey = 'mnscloud_phoneweb.accounts.v1';
  static const _contactsKey = 'mnscloud_phoneweb.contacts.v1';
  static const _historyKey = 'mnscloud_phoneweb.call_history.v1';
  static const _selectedAccountKey = 'mnscloud_phoneweb.selected_account.v1';
  static const _maxHistoryItems = 250;

  Future<StandalonePhoneWebState> load() async {
    return StandalonePhoneWebState(
      accounts: _decodeList(_read(_accountsKey), WebRtcAccount.fromJson),
      contacts: _decodeList(_read(_contactsKey), PhoneContact.fromJson),
      callHistory: _decodeList(
        _read(_historyKey),
        PhoneCallHistoryEntry.fromJson,
      ),
      selectedAccountId: _read(_selectedAccountKey),
    );
  }

  Future<void> saveAccounts(
    List<WebRtcAccount> accounts, {
    String? selectedAccountId,
  }) async {
    _write(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
    if (selectedAccountId == null || selectedAccountId.isEmpty) {
      _remove(_selectedAccountKey);
    } else {
      _write(_selectedAccountKey, selectedAccountId);
    }
  }

  Future<void> saveContacts(List<PhoneContact> contacts) async {
    final manualContacts = contacts
        .where((contact) => contact.source == PhoneContactSource.manual)
        .map((contact) => contact.toJson())
        .toList();
    _write(_contactsKey, jsonEncode(manualContacts));
  }

  Future<void> saveCallHistory(List<PhoneCallHistoryEntry> entries) async {
    final limited = entries.take(_maxHistoryItems).toList();
    _write(
      _historyKey,
      jsonEncode(limited.map((entry) => entry.toJson()).toList()),
    );
  }

  String? _read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  void _write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  void _remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
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
