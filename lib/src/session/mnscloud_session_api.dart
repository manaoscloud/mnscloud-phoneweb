import 'dart:convert';

import 'package:http/http.dart' as http;

/// Failure of an MNSCloud PhoneWeb API call, with the stable API `code`.
class MnscloudApiException implements Exception {
  const MnscloudApiException(
    this.code,
    this.message, {
    this.status = 0,
    this.tenants = const [],
  });

  final String code;
  final String message;
  final int status;

  /// Filled for `PHONE_TENANT_SELECTION_REQUIRED`.
  final List<MnscloudTenantChoice> tenants;

  @override
  String toString() => 'MnscloudApiException($code, $status)';
}

class MnscloudTenantChoice {
  const MnscloudTenantChoice({required this.uuid, required this.name});

  final String uuid;
  final String name;
}

/// Session returned by the API (`/phone/auth/*`). Holds no secret except
/// [refreshToken], which only native clients receive (web uses an HttpOnly
/// cookie the app never sees).
class MnscloudSessionGrant {
  const MnscloudSessionGrant({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshToken,
    required this.sessionUUID,
    required this.phoneUserUUID,
    required this.tenantUUID,
    required this.realm,
    required this.displayName,
    required this.customerUUID,
    required this.expiresAt,
  });

  final String accessToken;
  final Duration expiresIn;
  final String? refreshToken;
  final String sessionUUID;
  final String phoneUserUUID;
  final String tenantUUID;
  final String realm;
  final String? displayName;
  final String? customerUUID;
  final DateTime? expiresAt;

  factory MnscloudSessionGrant.fromJson(Map<String, dynamic> data) {
    final session = (data['session'] as Map?)?.cast<String, dynamic>() ?? {};
    String? text(Object? value) {
      final result = value?.toString().trim();
      return result == null || result.isEmpty ? null : result;
    }

    return MnscloudSessionGrant(
      accessToken: data['accessToken']?.toString() ?? '',
      expiresIn: Duration(seconds: (data['expiresIn'] as num?)?.toInt() ?? 600),
      refreshToken: text(data['refreshToken']),
      sessionUUID: session['sessionUUID']?.toString() ?? '',
      phoneUserUUID: session['phoneUserUUID']?.toString() ?? '',
      tenantUUID: session['tenantUUID']?.toString() ?? '',
      realm: session['realm']?.toString() ?? 'user',
      displayName: text(session['displayName']),
      customerUUID: text(session['customerUUID']),
      expiresAt: DateTime.tryParse(session['expiresAt']?.toString() ?? ''),
    );
  }
}

/// Thin client of the public PhoneWeb API. Sends no credentials it was not
/// given and keeps no state.
class MnscloudSessionApi {
  MnscloudSessionApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// API root, for example `https://tenant.example.com/api/v1`.
  final Uri baseUrl;
  final http.Client _client;

  Future<MnscloudSessionGrant> signIn({
    required String identifier,
    required String password,
    required String clientKind,
    String? tenantUUID,
    String? deviceName,
    String? platform,
  }) async {
    return _grant('phone/auth/signin', {
      'identifier': identifier,
      'password': password,
      'clientKind': clientKind,
      'tenantUUID': ?tenantUUID,
      'deviceName': ?deviceName,
      'platform': ?platform,
    });
  }

  Future<MnscloudSessionGrant> exchange({
    required String code,
    required String clientKind,
    String? deviceName,
    String? platform,
  }) async {
    return _grant('phone/auth/exchange', {
      'code': code,
      'clientKind': clientKind,
      'deviceName': ?deviceName,
      'platform': ?platform,
    });
  }

  /// Native: pass the stored refresh token. Web: pass null (HttpOnly cookie).
  Future<MnscloudSessionGrant> refresh(String? refreshToken) async {
    return _grant('phone/auth/refresh', {'refreshToken': ?refreshToken});
  }

  Future<void> signOut(String accessToken) async {
    try {
      await _client.post(
        baseUrl.resolve('phone/auth/signout'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } catch (_) {
      // Signing out locally must not depend on the network.
    }
  }

  Future<MnscloudSessionGrant> _grant(
    String path,
    Map<String, Object?> body,
  ) async {
    final http.Response response;
    try {
      response = await _client.post(
        baseUrl.resolve(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {
      throw const MnscloudApiException(
        'NETWORK_ERROR',
        'Could not reach the MNSCloud server.',
      );
    }
    final decoded = _decode(response.body);
    if (response.statusCode == 200 && decoded['data'] is Map) {
      return MnscloudSessionGrant.fromJson(
        (decoded['data'] as Map).cast<String, dynamic>(),
      );
    }
    final tenants = (decoded['tenants'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => MnscloudTenantChoice(
            uuid: item['tenantUUID']?.toString() ?? '',
            name: item['tenantName']?.toString() ?? '',
          ),
        )
        .where((tenant) => tenant.uuid.isNotEmpty)
        .toList();
    throw MnscloudApiException(
      decoded['code']?.toString() ?? 'HTTP_${response.statusCode}',
      decoded['error']?.toString() ??
          'The MNSCloud server refused the request.',
      status: response.statusCode,
      tenants: tenants,
    );
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
