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

  factory PhoneContact.fromJson(Map<String, dynamic> json) {
    return PhoneContact(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      number: json['number'] as String? ?? '',
      company: json['company'] as String? ?? '',
      source: PhoneContactSource.values.firstWhere(
        (source) => source.name == json['source'],
        orElse: () => PhoneContactSource.manual,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'company': company,
      'source': source.name,
    };
  }
}

class PhoneCallHistoryEntry {
  const PhoneCallHistoryEntry({
    required this.id,
    required this.remoteIdentity,
    required this.direction,
    required this.status,
    required this.startedAt,
    required this.durationSeconds,
    this.accountName = '',
  });

  final String id;
  final String remoteIdentity;
  final PhoneCallDirection direction;
  final PhoneCallStatus status;
  final DateTime startedAt;
  final int durationSeconds;
  final String accountName;

  factory PhoneCallHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PhoneCallHistoryEntry(
      id: json['id'] as String? ?? '',
      remoteIdentity: json['remoteIdentity'] as String? ?? '',
      direction: PhoneCallDirection.values.firstWhere(
        (direction) => direction.name == json['direction'],
        orElse: () => PhoneCallDirection.incoming,
      ),
      status: PhoneCallStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => PhoneCallStatus.completed,
      ),
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      accountName: json['accountName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'remoteIdentity': remoteIdentity,
      'direction': direction.name,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'accountName': accountName,
    };
  }
}

enum PhoneCallDirection { incoming, outgoing }

enum PhoneCallStatus { completed, missed, failed }

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
