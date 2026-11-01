import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local PhoneWeb data on native builds (`docs/security.md`): the operating
/// system keychain or keystore through `flutter_secure_storage`. Releases
/// before v0.1.80 kept the same records in clear in `shared_preferences`
/// (`mnscloud_phoneweb.<name>.v1`); they are read once and removed after the
/// secure copy is written.
class LocalDataVault {
  LocalDataVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String name) => 'phoneweb:$name';
  static String _legacyKey(String name) => 'mnscloud_phoneweb.$name.v1';

  Future<String?> read(String name) async {
    try {
      return await _storage.read(key: _key(name));
    } catch (_) {
      return null;
    }
  }

  /// False when nothing was stored: the caller keeps the value in memory.
  Future<bool> write(String name, String value) async {
    try {
      await _storage.write(key: _key(name), value: value);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String name) async {
    try {
      await _storage.delete(key: _key(name));
    } catch (_) {}
  }

  Future<String?> readLegacy(String name) async {
    try {
      return (await SharedPreferences.getInstance()).getString(
        _legacyKey(name),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeLegacy(String name, String value) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _legacyKey(name),
        value,
      );
    } catch (_) {}
  }

  Future<void> removeLegacy(String name) async {
    try {
      await (await SharedPreferences.getInstance()).remove(_legacyKey(name));
    } catch (_) {}
  }
}
