import 'phone_contact.dart';
import 'native_contacts_repository_stub.dart'
    if (dart.library.io) 'native_contacts_repository_io.dart'
    as impl;

abstract class NativeContactsRepository {
  factory NativeContactsRepository() = impl.NativeContactsRepositoryImpl;

  bool get isSupported;
  String get platformLabel;

  Future<NativeContactsResult> loadContacts({int limit = 5000});
}
