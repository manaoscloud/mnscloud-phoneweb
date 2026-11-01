import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/account/webrtc_account.dart';
import 'package:mnscloud_phoneweb/src/contacts/phone_contact.dart';
import 'package:mnscloud_phoneweb/src/storage/local_data_vault.dart';
import 'package:mnscloud_phoneweb/src/storage/standalone_phoneweb_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'persists standalone accounts, contacts, history and selection',
    () async {
      final store = StandalonePhoneWebStore();
      final account = WebRtcAccount(
        id: 'acc-1',
        name: 'Conta Softswitch',
        displayName: 'DBA270C728ED',
        username: 'DBA270C728ED',
        password: 'secret',
        domain: 'softswitch.example.com',
        wssServer: 'wss://webrtc.example.com/ws',
        stunServer: 'stun:stun.example.com:3478',
        turnServer: '',
        hasPassword: true,
        allowInsecureTransport: false,
        codecPolicy: WebRtcCodecPolicy.automaticRecommended,
        enabled: true,
        autoRegister: true,
        status: RegistrationStatus.registered,
      );
      final contact = PhoneContact(
        id: 'contact-1',
        name: 'Cliente',
        number: '559230423000',
        source: PhoneContactSource.manual,
      );
      final nativeContact = PhoneContact(
        id: 'native-1',
        name: 'Native',
        number: '1000',
        source: PhoneContactSource.native,
      );
      final history = PhoneCallHistoryEntry(
        id: 'call-1',
        remoteIdentity: '5511917702001',
        direction: PhoneCallDirection.incoming,
        status: PhoneCallStatus.completed,
        startedAt: DateTime.utc(2026, 8, 12, 14, 0),
        durationSeconds: 42,
        accountName: 'Conta Softswitch',
        diagnostic: 'SIP 486 · Busy Here',
      );

      await store.saveAccounts([account], selectedAccountId: account.id);
      await store.saveContacts([contact, nativeContact]);
      await store.saveCallHistory([history]);

      final loaded = await store.load();

      expect(loaded.selectedAccountId, account.id);
      expect(loaded.accounts, hasLength(1));
      expect(loaded.accounts.single.password, 'secret');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty, reason: 'nothing in clear preferences');
      final secure = await const FlutterSecureStorage().readAll();
      expect(secure['phoneweb:accounts'], isNot(contains('secret')));
      expect(secure['phoneweb:contacts'], contains('Cliente'));
      expect(secure['phoneweb:call_history'], contains('5511917702001'));
      expect(secure['phoneweb:selected_account'], account.id);
      expect(loaded.accounts.single.status, RegistrationStatus.offline);
      expect(loaded.contacts, hasLength(1));
      expect(loaded.contacts.single.id, contact.id);
      expect(loaded.callHistory, hasLength(1));
      expect(loaded.callHistory.single.durationSeconds, 42);
      expect(loaded.callHistory.single.diagnostic, 'SIP 486 · Busy Here');
    },
  );

  test('moves legacy plain-text passwords into the secret store', () async {
    SharedPreferences.setMockInitialValues({
      'mnscloud_phoneweb.accounts.v1': jsonEncode([
        {
          'id': 'legacy-1',
          'name': 'Legacy',
          'displayName': 'Legacy',
          'username': '1001',
          'password': 'legacy-secret',
          'domain': 'pbx.example.com',
          'wssServer': 'wss://pbx.example.com/ws',
          'hasPassword': true,
        },
      ]),
    });
    final store = StandalonePhoneWebStore();

    final first = await store.load();
    expect(first.accounts.single.password, 'legacy-secret');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mnscloud_phoneweb.accounts.v1'), isNull);
    final secure = await const FlutterSecureStorage().readAll();
    expect(secure['phoneweb:accounts'], contains('Legacy'));
    expect(secure['phoneweb:accounts'], isNot(contains('legacy-secret')));

    final second = await store.load();
    expect(second.accounts.single.password, 'legacy-secret');
  });

  test('removing an account deletes its stored password', () async {
    final store = StandalonePhoneWebStore();
    final account = WebRtcAccount.fromJson({
      'id': 'acc-2',
      'name': 'Remove me',
      'username': '1002',
      'password': 'to-delete',
      'domain': 'pbx.example.com',
      'wssServer': 'wss://pbx.example.com/ws',
    });
    await store.saveAccounts([account]);
    await store.saveAccounts([]);
    await store.saveAccounts([account.copyWith(password: '')]);

    final loaded = await store.load();
    expect(loaded.accounts.single.password, isEmpty);
  });

  test('moves clear contacts, history and selection of older releases into secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'mnscloud_phoneweb.contacts.v1': jsonEncode([
        {
          'id': 'c-1',
          'name': 'Old contact',
          'number': '1001',
          'source': 'manual',
        },
      ]),
      'mnscloud_phoneweb.call_history.v1': jsonEncode([
        {
          'id': 'h-1',
          'remoteIdentity': '5592999990000',
          'direction': 'outgoing',
          'status': 'completed',
          'startedAt': '2026-10-01T12:00:00.000Z',
        },
      ]),
      'mnscloud_phoneweb.selected_account.v1': 'acc-9',
      'phoneweb.language': 'pt-BR',
    });

    final loaded = await StandalonePhoneWebStore().load();

    expect(loaded.contacts.single.name, 'Old contact');
    expect(loaded.callHistory.single.remoteIdentity, '5592999990000');
    expect(loaded.selectedAccountId, 'acc-9');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'phoneweb.language'});
    final again = await StandalonePhoneWebStore().load();
    expect(again.contacts.single.name, 'Old contact');
    expect(again.callHistory, hasLength(1));
  });

  test('without secure storage nothing is written in clear', () async {
    SharedPreferences.setMockInitialValues({
      'mnscloud_phoneweb.contacts.v1': jsonEncode([
        {'id': 'c-1', 'name': 'Kept', 'number': '1001', 'source': 'manual'},
      ]),
    });
    final store = StandalonePhoneWebStore(vault: _ReadOnlyVault());

    final loaded = await store.load();
    expect(loaded.contacts.single.name, 'Kept');
    await store.saveContacts([
      PhoneContact(
        id: 'c-2',
        name: 'New',
        number: '2002',
        source: PhoneContactSource.manual,
      ),
    ]);
    await store.saveCallHistory([
      PhoneCallHistoryEntry(
        id: 'h-2',
        remoteIdentity: '2002',
        direction: PhoneCallDirection.outgoing,
        status: PhoneCallStatus.completed,
        startedAt: DateTime.utc(2026, 11, 1),
        durationSeconds: 0,
      ),
    ]);

    final prefs = await SharedPreferences.getInstance();
    // The clear record of the older release stays readable; nothing new joins it.
    expect(prefs.getString('mnscloud_phoneweb.contacts.v1'), contains('Kept'));
    expect(
      prefs.getString('mnscloud_phoneweb.contacts.v1'),
      isNot(contains('New')),
    );
    expect(prefs.getString('mnscloud_phoneweb.call_history.v1'), isNull);
  });
}

class _ReadOnlyVault extends LocalDataVault {
  @override
  Future<bool> write(String name, String value) async => false;
}
