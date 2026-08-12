import 'package:flutter_test/flutter_test.dart';
import 'package:mnscloud_phoneweb/src/account/webrtc_account.dart';
import 'package:mnscloud_phoneweb/src/contacts/phone_contact.dart';
import 'package:mnscloud_phoneweb/src/storage/standalone_phoneweb_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      expect(loaded.accounts.single.status, RegistrationStatus.offline);
      expect(loaded.contacts, hasLength(1));
      expect(loaded.contacts.single.id, contact.id);
      expect(loaded.callHistory, hasLength(1));
      expect(loaded.callHistory.single.durationSeconds, 42);
      expect(loaded.callHistory.single.diagnostic, 'SIP 486 · Busy Here');
    },
  );
}
