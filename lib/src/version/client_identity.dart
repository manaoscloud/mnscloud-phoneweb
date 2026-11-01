import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_build_info.dart';
import 'client_platform_io.dart'
    if (dart.library.js_interop) 'client_platform_web.dart'
    as platform;
import 'runtime_version.dart';

/// `X-Mns-Client` value of this build, `<product>/<x.y.z>`.
String get mnscloudClientId =>
    '${appBuildInfo.product}/${normalizeVersion(appBuildInfo.version)}';

/// `X-Mns-Client-Platform` value: `web`, or the OS of an installed app.
String get mnscloudClientPlatform => platform.currentClientPlatform();

/// Headers every MNSCloud API call of PhoneWeb carries.
Map<String, String> get mnscloudClientHeaders => {
  'X-Mns-Client': mnscloudClientId,
  'X-Mns-Client-Platform': mnscloudClientPlatform,
};

/// Raised (never cleared) when the API answers 426 `CLIENT_VERSION_UNSUPPORTED`:
/// the running version is below the minimum of its platform.
final ValueNotifier<bool> clientVersionUnsupported = ValueNotifier<bool>(false);

const _unsupportedCode = 'CLIENT_VERSION_UNSUPPORTED';

/// The one HTTP path of PhoneWeb to the MNSCloud API (`/api/v1`): adds the
/// client identity headers and reports a 426 `CLIENT_VERSION_UNSUPPORTED`
/// through [clientVersionUnsupported]. Responses are passed through unchanged.
class MnscloudApiClient extends http.BaseClient {
  MnscloudApiClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(mnscloudClientHeaders);
    final response = await _inner.send(request);
    if (response.statusCode != 426) return response;
    final bytes = await response.stream.toBytes();
    if (_isUnsupported(bytes)) clientVersionUnsupported.value = true;
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  static bool _isUnsupported(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map && decoded['code'] == _unsupportedCode;
    } catch (_) {
      return false;
    }
  }

  @override
  void close() => _inner.close();
}
