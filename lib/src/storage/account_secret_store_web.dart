import 'package:web/web.dart' as web;

import 'web_cipher.dart';

/// SIP passwords of manual accounts on the web build (`docs/security.md`).
///
/// Each password is encrypted by [WebCipher] (AES-GCM, non-extractable key in
/// IndexedDB); `localStorage` holds the ciphertext, never the password or the
/// key. Without WebCrypto or IndexedDB passwords are kept in memory only and
/// must be typed again after a reload.
class AccountSecretStore {
  AccountSecretStore({WebCipher? cipher})
    : _cipher = cipher ?? WebCipher.instance;

  final WebCipher _cipher;
  static const _secretPrefix = 'mnscloud_phoneweb.secret.v1.';

  Future<String?> readPassword(String accountId) async {
    final stored = _read('$_secretPrefix$accountId');
    return stored == null ? null : _cipher.decrypt(stored);
  }

  Future<void> writePassword(String accountId, String password) async {
    final sealed = await _cipher.encrypt(password);
    if (sealed != null) _write('$_secretPrefix$accountId', sealed);
  }

  Future<void> deletePassword(String accountId) async {
    try {
      web.window.localStorage.removeItem('$_secretPrefix$accountId');
    } catch (_) {}
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
}
