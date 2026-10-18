import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SIP passwords of manual accounts, kept outside the account metadata
/// (`docs/security.md`). Native builds use the operating system keychain or
/// keystore through `flutter_secure_storage`.
class AccountSecretStore {
  AccountSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _passwordKey(String accountId) =>
      'account:$accountId:sip_password';

  Future<String?> readPassword(String accountId) async {
    try {
      return await _storage.read(key: _passwordKey(accountId));
    } catch (_) {
      return null;
    }
  }

  Future<void> writePassword(String accountId, String password) async {
    try {
      await _storage.write(key: _passwordKey(accountId), value: password);
    } catch (_) {}
  }

  Future<void> deletePassword(String accountId) async {
    try {
      await _storage.delete(key: _passwordKey(accountId));
    } catch (_) {}
  }
}
