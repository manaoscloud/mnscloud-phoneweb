import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// SIP passwords of manual accounts on the web build (`docs/security.md`).
///
/// Each password is encrypted with AES-GCM using a non-extractable WebCrypto
/// key that lives only in IndexedDB; `localStorage` holds the ciphertext, never
/// the password or the key. Without WebCrypto or IndexedDB (insecure context,
/// blocked storage) passwords are kept in memory only and must be typed again
/// after a reload.
class AccountSecretStore {
  static const _secretPrefix = 'mnscloud_phoneweb.secret.v1.';
  static const _dbName = 'mnscloud_phoneweb_keys';
  static const _storeName = 'keys';
  static const _keyId = 'account-secrets.v1';

  JSObject? _cachedKey;

  Future<String?> readPassword(String accountId) async {
    final stored = _read('$_secretPrefix$accountId');
    if (stored == null) return null;
    final parts = stored.split('.');
    if (parts.length != 2) return null;
    try {
      final key = await _key(create: false);
      if (key == null) return null;
      final plain = await _subtle('decrypt', [
        _gcm(base64Url.decode(parts[0])),
        key,
        base64Url.decode(parts[1]).toJS,
      ]);
      return utf8.decode((plain as JSArrayBuffer).toDart.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<void> writePassword(String accountId, String password) async {
    try {
      final key = await _key(create: true);
      if (key == null) return;
      final iv = _randomBytes(12);
      final encrypted = await _subtle('encrypt', [
        _gcm(iv),
        key,
        Uint8List.fromList(utf8.encode(password)).toJS,
      ]);
      final cipher = (encrypted as JSArrayBuffer).toDart.asUint8List();
      _write(
        '$_secretPrefix$accountId',
        '${base64Url.encode(iv)}.${base64Url.encode(cipher)}',
      );
    } catch (_) {}
  }

  Future<void> deletePassword(String accountId) async {
    try {
      web.window.localStorage.removeItem('$_secretPrefix$accountId');
    } catch (_) {}
  }

  JSObject _gcm(List<int> iv) {
    final params = JSObject();
    params['name'] = 'AES-GCM'.toJS;
    params['iv'] = Uint8List.fromList(iv).toJS;
    return params;
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    final array = bytes.toJS;
    (globalContext['crypto'] as JSObject).callMethod(
      'getRandomValues'.toJS,
      array,
    );
    return array.toDart;
  }

  Future<JSAny?> _subtle(String method, List<JSAny?> args) {
    final subtle = (globalContext['crypto'] as JSObject)['subtle'] as JSObject;
    return (subtle.callMethodVarArgs<JSPromise<JSAny?>>(
      method.toJS,
      args,
    )).toDart;
  }

  Future<JSObject?> _key({required bool create}) async {
    if (_cachedKey != null) return _cachedKey;
    final db = await _openDb();
    if (db == null) return null;
    final existing = await _request(
      _objectStore(
        db,
        'readonly',
      ).callMethod<JSObject>('get'.toJS, _keyId.toJS),
    );
    if (existing != null && existing.isA<JSObject>()) {
      return _cachedKey = existing as JSObject;
    }
    if (!create) return null;
    final algorithm = JSObject();
    algorithm['name'] = 'AES-GCM'.toJS;
    algorithm['length'] = 256.toJS;
    final key =
        await _subtle('generateKey', [
              algorithm,
              false.toJS,
              <JSString>['encrypt'.toJS, 'decrypt'.toJS].toJS,
            ])
            as JSObject;
    await _request(
      _objectStore(
        db,
        'readwrite',
      ).callMethod<JSObject>('put'.toJS, key, _keyId.toJS),
    );
    return _cachedKey = key;
  }

  JSObject _objectStore(JSObject db, String mode) {
    final tx = db.callMethod<JSObject>(
      'transaction'.toJS,
      _storeName.toJS,
      mode.toJS,
    );
    return tx.callMethod<JSObject>('objectStore'.toJS, _storeName.toJS);
  }

  Future<JSObject?> _openDb() async {
    try {
      final factory = globalContext['indexedDB'];
      if (factory == null || !factory.isA<JSObject>()) return null;
      final request = (factory as JSObject).callMethod<JSObject>(
        'open'.toJS,
        _dbName.toJS,
        1.toJS,
      );
      request['onupgradeneeded'] = ((JSAny _) {
        final db = request['result'] as JSObject;
        db.callMethod('createObjectStore'.toJS, _storeName.toJS);
      }).toJS;
      final db = await _request(request);
      return db != null && db.isA<JSObject>() ? db as JSObject : null;
    } catch (_) {
      return null;
    }
  }

  Future<JSAny?> _request(JSObject request) {
    final completer = Completer<JSAny?>();
    request['onsuccess'] = ((JSAny _) {
      if (!completer.isCompleted) completer.complete(request['result']);
    }).toJS;
    request['onerror'] = ((JSAny _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('IndexedDB request failed'));
      }
    }).toJS;
    return completer.future;
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
