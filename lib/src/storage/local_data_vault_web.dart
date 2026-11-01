import 'package:web/web.dart' as web;

import 'web_cipher.dart';

/// Local PhoneWeb data on the web build (`docs/security.md`): AES-GCM
/// ciphertext in `localStorage` (`mnscloud_phoneweb.<name>.v2`), sealed by
/// [WebCipher]. Releases before v0.1.80 kept the same records in clear
/// (`mnscloud_phoneweb.<name>.v1`); they are read once and removed after the
/// encrypted copy is written.
class LocalDataVault {
  LocalDataVault({WebCipher? cipher}) : _cipher = cipher ?? WebCipher.instance;

  final WebCipher _cipher;

  static String _key(String name) => 'mnscloud_phoneweb.$name.v2';
  static String _legacyKey(String name) => 'mnscloud_phoneweb.$name.v1';

  Future<String?> read(String name) async {
    final sealed = _get(_key(name));
    return sealed == null ? null : _cipher.decrypt(sealed);
  }

  /// False when nothing was stored (no WebCrypto, IndexedDB or quota): the
  /// caller keeps the value in memory, never in clear.
  Future<bool> write(String name, String value) async {
    final sealed = await _cipher.encrypt(value);
    return sealed != null && _set(_key(name), sealed);
  }

  Future<void> remove(String name) async => _remove(_key(name));

  Future<String?> readLegacy(String name) async => _get(_legacyKey(name));

  Future<void> writeLegacy(String name, String value) async =>
      _set(_legacyKey(name), value);

  Future<void> removeLegacy(String name) async => _remove(_legacyKey(name));

  String? _get(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  bool _set(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
