import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'runtime_version.dart';

Future<RuntimeReleaseInfo?> fetchLatestRuntimeRelease(String product) async {
  final base = web.window.location.origin;
  final url =
      '$base/api/v1/runtime/releases/latest?product=${Uri.encodeQueryComponent(product)}';

  try {
    final response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) return null;

    final body = (await response.text().toDart).toDart;
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return null;

    final version = data['version']?.toString().trim();
    if (version == null || version.isEmpty) return null;

    final buildRef = data['buildRef']?.toString().trim();
    return RuntimeReleaseInfo(
      version: version,
      buildRef: buildRef == null || buildRef.isEmpty ? null : buildRef,
    );
  } catch (_) {
    return null;
  }
}
