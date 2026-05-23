class PhoneContact {
  PhoneContact({
    required this.id,
    required this.name,
    required this.number,
    this.company = '',
    this.source = PhoneContactSource.manual,
  });

  final String id;
  final String name;
  final String number;
  final String company;
  final PhoneContactSource source;
}

enum PhoneContactSource { manual, native }

enum NativeContactsStatus {
  loaded,
  unsupported,
  permissionDenied,
  permissionPermanentlyDenied,
  failed,
}

class NativeContactsResult {
  const NativeContactsResult({
    required this.status,
    required this.contacts,
    required this.message,
    required this.platformLabel,
  });

  final NativeContactsStatus status;
  final List<PhoneContact> contacts;
  final String message;
  final String platformLabel;

  bool get hasContacts => contacts.isNotEmpty;
}
