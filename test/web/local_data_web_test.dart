@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/account/webrtc_account.dart';
import 'package:mnscloud_phoneweb/src/contacts/phone_contact.dart';
import 'package:mnscloud_phoneweb/src/storage/account_secret_store.dart';
import 'package:mnscloud_phoneweb/src/storage/local_data_vault.dart';
import 'package:mnscloud_phoneweb/src/storage/standalone_phoneweb_store.dart';
import 'package:mnscloud_phoneweb/src/storage/web_cipher.dart';
import 'package:web/web.dart' as web;

/// Real browser storage: `localStorage` must never hold the data in clear.
/// Run with `flutter test --platform chrome test/web`.
StandalonePhoneWebStore reopened() {
  final cipher = WebCipher();
  return StandalonePhoneWebStore(
    secrets: AccountSecretStore(cipher: cipher),
    vault: LocalDataVault(cipher: cipher),
  );
}

/// Stored values (key names carry only internal account IDs).
String everything() {
  final storage = web.window.localStorage;
  return [
    for (var i = 0; i < storage.length; i++)
      '${storage.key(i)}=${storage.getItem(storage.key(i)!)}',
  ].join('\n');
}

String values() {
  final storage = web.window.localStorage;
  return [
    for (var i = 0; i < storage.length; i++) storage.getItem(storage.key(i)!),
  ].join('\n');
}

void main() {
  setUp(() => web.window.localStorage.clear());

  test(
    'older clear records move to ciphertext and read back after a reload',
    () async {
      final storage = web.window.localStorage;
      storage.setItem(
        'mnscloud_phoneweb.accounts.v1',
        jsonEncode([
          {
            'id': 'legacy-1',
            'name': 'Ramal Recepção',
            'username': '1001',
            'password': 'legacy-secret',
            'domain': 'pbx.example.com',
            'wssServer': 'wss://pbx.example.com/ws',
          },
        ]),
      );
      storage.setItem(
        'mnscloud_phoneweb.contacts.v1',
        jsonEncode([
          {
            'id': 'c-1',
            'name': 'Maria Cliente',
            'number': '5592988887777',
            'source': 'manual',
          },
        ]),
      );
      storage.setItem(
        'mnscloud_phoneweb.call_history.v1',
        jsonEncode([
          {
            'id': 'h-1',
            'remoteIdentity': '5592977776666',
            'direction': 'incoming',
            'status': 'completed',
            'startedAt': '2026-10-01T12:00:00.000Z',
          },
        ]),
      );
      storage.setItem('mnscloud_phoneweb.selected_account.v1', 'legacy-1');

      final first = await reopened().load();
      expect(first.accounts.single.password, 'legacy-secret');
      expect(first.contacts.single.name, 'Maria Cliente');
      expect(first.callHistory.single.remoteIdentity, '5592977776666');
      expect(first.selectedAccountId, 'legacy-1');

      final stored = everything();
      for (final clear in [
        'legacy-secret',
        'Ramal',
        'pbx.example.com',
        'Maria',
        '5592988887777',
        '5592977776666',
      ]) {
        expect(
          stored,
          isNot(contains(clear)),
          reason: '"$clear" left in clear',
        );
      }
      expect(stored, isNot(contains('.v1=')));

      final second = await reopened().load();
      expect(second.accounts.single.password, 'legacy-secret');
      expect(second.accounts.single.domain, 'pbx.example.com');
      expect(second.contacts.single.number, '5592988887777');
      expect(second.callHistory, hasLength(1));
      expect(second.selectedAccountId, 'legacy-1');
    },
  );

  test('new saves are ciphertext only', () async {
    final store = reopened();
    await store.saveContacts([
      PhoneContact(
        id: 'c-2',
        name: 'João Fornecedor',
        number: '1133334444',
        source: PhoneContactSource.manual,
      ),
    ]);
    await store.saveCallHistory([
      PhoneCallHistoryEntry(
        id: 'h-2',
        remoteIdentity: '1133334444',
        direction: PhoneCallDirection.outgoing,
        status: PhoneCallStatus.completed,
        startedAt: DateTime.utc(2026, 11, 1),
        durationSeconds: 30,
      ),
    ]);
    await store.saveAccounts([
      WebRtcAccount.fromJson({
        'id': 'acc-3',
        'name': 'Conta Nova',
        'username': '2002',
        'password': 'new-secret',
        'domain': 'sip.example.org',
        'wssServer': 'wss://sip.example.org/ws',
      }),
    ], selectedAccountId: 'acc-3');

    expect(values(), isNot(contains('acc-3')));
    final stored = everything();
    for (final clear in [
      'João',
      '1133334444',
      'Conta Nova',
      'sip.example.org',
      'new-secret',
    ]) {
      expect(stored, isNot(contains(clear)), reason: '"$clear" left in clear');
    }
    final loaded = await reopened().load();
    expect(loaded.contacts.single.name, 'João Fornecedor');
    expect(loaded.callHistory.single.durationSeconds, 30);
    expect(loaded.accounts.single.password, 'new-secret');
    expect(loaded.selectedAccountId, 'acc-3');
  });

  test('two first writes at once share one key', () async {
    final cipher = WebCipher();
    final sealed = await Future.wait([
      cipher.encrypt('a'),
      cipher.encrypt('b'),
    ]);
    final other = WebCipher();
    expect(await other.decrypt(sealed[0]!), 'a');
    expect(await other.decrypt(sealed[1]!), 'b');
  });
}
