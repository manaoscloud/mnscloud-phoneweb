import 'dart:convert';
import 'package:http/http.dart' as http;
import '../session/mnscloud_session_api.dart';

/// Authenticated agent transport. Credentials stay in memory and never enter URLs.
class AgentApi {
  AgentApi(this.root, {http.Client? client})
    : _client = client ?? http.Client();
  final Uri root;
  final http.Client _client;

  Future<Map<String, dynamic>> request(
    String token, {
    String? action,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(
      action == null ? 'GET' : 'POST',
      root.resolve('phone/agent/${action ?? ''}'),
    )..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw MnscloudApiException(
        decoded['code']?.toString() ?? 'REQUEST_FAILED',
        'Unable to update agent state.',
        status: response.statusCode,
      );
    }
    return (decoded['data'] as Map).cast<String, dynamic>();
  }

  Stream<Map<String, dynamic>> events(String token, String cursor) async* {
    final request = http.Request('GET', root.resolve('phone/agent/events'))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Last-Event-ID'] = cursor;
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw const MnscloudApiException(
        'STREAM_CLOSED',
        'Agent updates disconnected.',
      );
    }
    String? event;
    String? id;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('id: ')) id = line.substring(4);
      if (line.startsWith('event: ')) event = line.substring(7);
      if (line.startsWith('data: ') && event == 'snapshot') {
        final data = (jsonDecode(line.substring(6)) as Map)
            .cast<String, dynamic>();
        yield {...data, '_cursor': id};
      }
    }
  }

  void close() => _client.close();
}
