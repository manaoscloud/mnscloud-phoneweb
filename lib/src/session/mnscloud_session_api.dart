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

/// A line of the signed-in phone user (no secret).
class MnscloudLine {
  const MnscloudLine({
    required this.lineKey,
    required this.source,
    required this.mode,
    required this.primary,
    required this.webrtcReady,
    required this.username,
    required this.label,
    required this.domain,
    this.claimExpiresAt,
    this.kind = 'pabx',
  });

  final String kind;
  final String lineKey;
  final String source;
  final String mode;
  final bool primary;
  final bool webrtcReady;
  final String username;
  final String label;
  final String? domain;
  final DateTime? claimExpiresAt;

  bool get claimed => source == 'claimed';

  factory MnscloudLine.fromJson(Map<String, dynamic> json) => MnscloudLine(
    kind: json['kind']?.toString() ?? '',
    lineKey: json['lineKey']?.toString() ?? '',
    source: json['source']?.toString() ?? 'assigned',
    mode: json['mode']?.toString() ?? 'dedicated',
    primary: json['primary'] == true,
    webrtcReady: json['webrtcReady'] == true,
    username: json['username']?.toString() ?? '',
    label: json['label']?.toString() ?? json['username']?.toString() ?? '',
    domain: json['domain']?.toString(),
    claimExpiresAt: DateTime.tryParse(json['claimExpiresAt']?.toString() ?? ''),
  );
}

/// A free pool line the phone user can take.
class MnscloudAvailableLine {
  const MnscloudAvailableLine({
    required this.poolUUID,
    required this.label,
    this.notes,
  });

  final String poolUUID;
  final String label;
  final String? notes;

  factory MnscloudAvailableLine.fromJson(Map<String, dynamic> json) =>
      MnscloudAvailableLine(
        poolUUID: json['poolUUID']?.toString() ?? '',
        label: json['label']?.toString() ?? json['username']?.toString() ?? '',
        notes: json['notes']?.toString(),
      );
}

/// Registration data of one line. Contains the line secret: keep in memory only.
class MnscloudLineCredentials {
  const MnscloudLineCredentials({
    required this.lineKey,
    required this.label,
    required this.username,
    required this.password,
    required this.domain,
    required this.displayName,
    required this.wssUrl,
    required this.stunUrls,
    required this.turnUrls,
    this.iceServers = const [],
    this.iceExpiresAt,
  });

  final String lineKey;
  final String label;
  final String username;
  final String password;
  final String domain;
  final String? displayName;
  final String wssUrl;
  final List<String> stunUrls;
  final List<String> turnUrls;

  /// One entry per url, with the TURN REST username/credential when issued.
  final List<Map<String, String>> iceServers;
  final DateTime? iceExpiresAt;

  factory MnscloudLineCredentials.fromJson(Map<String, dynamic> json) {
    final sip = (json['sip'] as Map?)?.cast<String, dynamic>() ?? {};
    final urls = <String>[
      for (final server
          in (json['iceServers'] as List? ?? const []).whereType<Map>())
        for (final url in (server['urls'] as List? ?? const [])) url.toString(),
    ];
    return MnscloudLineCredentials(
      lineKey: json['lineKey']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      username: sip['username']?.toString() ?? '',
      password: sip['password']?.toString() ?? '',
      domain: sip['domain']?.toString() ?? '',
      displayName: sip['displayName']?.toString(),
      wssUrl: json['wssUrl']?.toString() ?? '',
      stunUrls: urls.where((url) => url.startsWith('stun')).toList(),
      turnUrls: urls.where((url) => url.startsWith('turn')).toList(),
      iceServers: [
        for (final server
            in (json['iceServers'] as List? ?? const []).whereType<Map>())
          for (final url in (server['urls'] as List? ?? const []))
            {
              'urls': url.toString(),
              if (server['username'] != null)
                'username': server['username'].toString(),
              if (server['credential'] != null)
                'credential': server['credential'].toString(),
            },
      ],
      iceExpiresAt: DateTime.tryParse(json['iceExpiresAt']?.toString() ?? ''),
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

  Future<List<MnscloudLine>> lines(String accessToken) async {
    final data = await _authorized('GET', 'phone/lines', accessToken);
    return _items(data).map(MnscloudLine.fromJson).toList();
  }

  Future<List<MnscloudAvailableLine>> availableLines(String accessToken) async {
    final data = await _authorized('GET', 'phone/lines/available', accessToken);
    return _items(data).map(MnscloudAvailableLine.fromJson).toList();
  }

  Future<void> claimLine(String accessToken, String poolUUID) async {
    await _authorized('POST', 'phone/lines/claims', accessToken, {
      'poolUUID': poolUUID,
    });
  }

  Future<void> releaseLine(String accessToken, String lineKey) async {
    await _authorized('DELETE', 'phone/lines/claims/$lineKey', accessToken);
  }

  Future<MnscloudLineCredentials> lineCredentials(
    String accessToken,
    String lineKey,
  ) async {
    final data = await _authorized(
      'POST',
      'phone/lines/$lineKey/credentials',
      accessToken,
    );
    return MnscloudLineCredentials.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  List<Map<String, dynamic>> _items(Object? data) {
    final items = data is Map ? data['items'] : null;
    return (items as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<Object?> _authorized(
    String method,
    String path,
    String accessToken, [
    Map<String, Object?>? body,
  ]) async {
    final http.Response response;
    try {
      final request = http.Request(method, baseUrl.resolve(path))
        ..headers['Authorization'] = 'Bearer $accessToken';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const MnscloudApiException(
        'NETWORK_ERROR',
        'Could not reach the MNSCloud server.',
      );
    }
    final decoded = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['data'];
    }
    throw MnscloudApiException(
      decoded['code']?.toString() ?? 'HTTP_${response.statusCode}',
      decoded['error']?.toString() ??
          'The MNSCloud server refused the request.',
      status: response.statusCode,
    );
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
