import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart' as native;

import 'native_contacts_repository.dart';
import 'phone_contact.dart';

class NativeContactsRepositoryImpl implements NativeContactsRepository {
  @override
  bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  String get platformLabel {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Desktop';
  }

  @override
  Future<NativeContactsResult> loadContacts({int limit = 5000}) async {
    if (!isSupported) {
      return NativeContactsResult(
        status: NativeContactsStatus.unsupported,
        contacts: const [],
        message:
            'Native contact access is not available on $platformLabel yet. Use Android, iOS, or macOS.',
        platformLabel: platformLabel,
      );
    }

    final permission = await native.FlutterContacts.permissions.request(
      native.PermissionType.read,
    );

    if (permission == native.PermissionStatus.permanentlyDenied ||
        permission == native.PermissionStatus.restricted) {
      return NativeContactsResult(
        status: NativeContactsStatus.permissionPermanentlyDenied,
        contacts: const [],
        message:
            'Contacts permission is blocked on $platformLabel. Enable it in system settings.',
        platformLabel: platformLabel,
      );
    }

    if (permission != native.PermissionStatus.granted &&
        permission != native.PermissionStatus.limited) {
      return NativeContactsResult(
        status: NativeContactsStatus.permissionDenied,
        contacts: const [],
        message: 'Contacts permission was not granted on $platformLabel.',
        platformLabel: platformLabel,
      );
    }

    try {
      final contacts = await native.FlutterContacts.getAll(
        properties: {
          native.ContactProperty.name,
          native.ContactProperty.phone,
          native.ContactProperty.organization,
        },
        limit: limit,
      );

      final mapped = <PhoneContact>[];
      for (final contact in contacts) {
        final displayName = (contact.displayName ?? '').trim();
        final fallbackName = [contact.name?.first, contact.name?.last]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join(' ');
        final name = displayName.isNotEmpty ? displayName : fallbackName;
        final company = contact.organizations.isEmpty
            ? ''
            : (contact.organizations.first.name ?? '').trim();

        for (var index = 0; index < contact.phones.length; index++) {
          final phone = contact.phones[index];
          final number = phone.number.trim();
          if (number.isEmpty) continue;

          mapped.add(
            PhoneContact(
              id: 'native:${platformLabel.toLowerCase()}:${contact.id ?? mapped.length}:$index',
              name: name.isEmpty ? number : name,
              number: number,
              company: company,
              source: PhoneContactSource.native,
            ),
          );
        }
      }

      mapped.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return NativeContactsResult(
        status: NativeContactsStatus.loaded,
        contacts: mapped,
        message: mapped.isEmpty
            ? 'No phone contacts were found on $platformLabel.'
            : '${mapped.length} native contacts synced from $platformLabel.',
        platformLabel: platformLabel,
      );
    } catch (error) {
      return NativeContactsResult(
        status: NativeContactsStatus.failed,
        contacts: const [],
        message: 'Could not sync contacts from $platformLabel: $error',
        platformLabel: platformLabel,
      );
    }
  }
}
