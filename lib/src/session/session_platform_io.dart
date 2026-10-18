import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Native builds keep the MNSCloud refresh token in the OS keychain/keystore.
class SessionPlatform {
  SessionPlatform({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshKey = 'mnscloud:phone_session:refresh_token';
  static const _serverKey = 'mnscloud:phone_session:server';
  final FlutterSecureStorage _storage;

  String get clientKind => 'native';

  String get platform => Platform.operatingSystem;

  /// Native apps have no hosting origin: the user types the MNSCloud server.
  Uri? get defaultServer => null;

  Future<String?> readServer() => _storage.read(key: _serverKey);

  Future<void> writeServer(String? server) => server == null
      ? _storage.delete(key: _serverKey)
      : _storage.write(key: _serverKey, value: server);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> writeRefreshToken(String? token) => token == null
      ? _storage.delete(key: _refreshKey)
      : _storage.write(key: _refreshKey, value: token);

  /// App handoff codes arrive only on the web build.
  String? takeHandoffCode() => null;
}
