import 'native_contacts_repository.dart';
import 'phone_contact.dart';

class NativeContactsRepositoryImpl implements NativeContactsRepository {
  @override
  bool get isSupported => false;

  @override
  String get platformLabel => 'Web';

  @override
  Future<NativeContactsResult> loadContacts({int limit = 5000}) async {
    return const NativeContactsResult(
      status: NativeContactsStatus.unsupported,
      contacts: [],
      message:
          'Native contact access is not available in the browser. Use Android, iOS, or macOS to sync the device address book.',
      platformLabel: 'Web',
    );
  }
}
