import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// AES-GCM for the data PhoneWeb keeps in the browser (`docs/security.md`).
///
/// The key is a **non-extractable** WebCrypto key that lives only in IndexedDB
/// (`mnscloud_phoneweb_keys`); what goes to `localStorage` is `<iv>.<cipher>`
/// in base64url. One key per origin, shared by SIP passwords and local data.
/// Without WebCrypto or IndexedDB (insecure context, blocked storage) every
/// method answers null and callers keep the data in memory only.
class WebCipher {
  /// A fresh instance reads the stored key again, as a page reload does.
  WebCipher();

  static final instance = WebCipher();

  static const _dbName = 'mnscloud_phoneweb_keys';
  static const _storeName = 'keys';
  static const _keyId = 'account-secrets.v1';

  Future<JSObject?>? _existing;
  Future<JSObject?>? _created;

  Future<String?> encrypt(String plain) async {
    try {
      final key = await _key(create: true);
      if (key == null) return null;
      final iv = _randomBytes(12);
      final encrypted = await _subtle('encrypt', [
        _gcm(iv),
        key,
        Uint8List.fromList(utf8.encode(plain)).toJS,
      ]);
      final cipher = (encrypted as JSArrayBuffer).toDart.asUint8List();
      return '${base64Url.encode(iv)}.${base64Url.encode(cipher)}';
    } catch (_) {
      return null;
    }
  }

  /// Null when [sealed] is not ours: wrong format, no key or another key.
  Future<String?> decrypt(String sealed) async {
    final parts = sealed.split('.');
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

  /// One lookup and at most one creation per page, so two first writes never
  /// make two keys; `add` keeps the key another tab created first.
  Future<JSObject?> _key({required bool create}) async {
    final existing = await (_existing ??= _load());
    if (existing != null || !create) return existing;
    JSObject? key;
    try {
      key = await (_created ??= _create());
    } catch (_) {
      _created = null;
      rethrow;
    }
    if (key == null) {
      _created = null;
    } else {
      _existing = Future.value(key);
    }
    return key;
  }

  Future<JSObject?> _load() async {
    try {
      final db = await _openDb();
      if (db == null) return null;
      final found = await _request(
        _objectStore(
          db,
          'readonly',
        ).callMethod<JSObject>('get'.toJS, _keyId.toJS),
      );
      return found != null && found.isA<JSObject>() ? found as JSObject : null;
    } catch (_) {
      return null;
    }
  }

  Future<JSObject?> _create() async {
    final db = await _openDb();
    if (db == null) return null;
    // Errors of generateKey reach the caller, which keeps the data in memory.
    final algorithm = JSObject();
    algorithm['name'] = 'AES-GCM'.toJS;
    algorithm['length'] = 256.toJS;
    final key = await _subtle('generateKey', [
      algorithm,
      false.toJS,
      <JSString>['encrypt'.toJS, 'decrypt'.toJS].toJS,
    ]) as JSObject;
    try {
      await _request(
        _objectStore(
          db,
          'readwrite',
        ).callMethod<JSObject>('add'.toJS, key, _keyId.toJS),
      );
      return key;
    } catch (_) {
      // Another tab stored its key first: use that one.
      return _load();
    }
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
    request['onerror'] = ((JSAny event) {
      // Handled here: an unhandled error would also abort the transaction loudly.
      if (event.isA<JSObject>()) {
        (event as JSObject).callMethod('preventDefault'.toJS);
      }
      if (!completer.isCompleted) {
        completer.completeError(StateError('IndexedDB request failed'));
      }
    }).toJS;
    return completer.future;
  }
}
