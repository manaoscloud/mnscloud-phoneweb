import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'client_identity.dart';
import 'runtime_version.dart';

/// Version policy of PhoneWeb published by the MNSCloud API.
class ClientVersionPolicy {
  const ClientVersionPolicy({this.latest, this.minimum = const {}});

  final String? latest;

  /// Lowest accepted version per installed platform (`android`, `ios`, ...).
  final Map<String, String> minimum;

  static ClientVersionPolicy? fromResponse(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return null;
    String? version(Object? value) {
      final text = normalizeVersion(value?.toString());
      return isReleaseVersion(text) ? text : null;
    }

    final minimum = <String, String>{};
    final raw = data['minimum'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final parsed = version(value);
        if (parsed != null) minimum[key.toString()] = parsed;
      });
    }
    return ClientVersionPolicy(
      latest: version(data['latest']),
      minimum: minimum,
    );
  }
}

/// Reads `GET <apiRoot>/public/clients/phoneweb/policy`; null on any failure.
Future<ClientVersionPolicy?> fetchClientVersionPolicy(
  Uri apiRoot, {
  http.Client? client,
}) async {
  final http0 = MnscloudApiClient(client);
  try {
    final response = await http0
        .get(apiRoot.resolve('public/clients/phoneweb/policy'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    return ClientVersionPolicy.fromResponse(jsonDecode(response.body));
  } catch (_) {
    return null;
  } finally {
    if (client == null) http0.close();
  }
}
