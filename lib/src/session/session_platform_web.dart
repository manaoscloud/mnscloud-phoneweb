import 'package:web/web.dart' as web;

/// Web/PWA: the refresh token is an HttpOnly cookie set by the API, so the
/// app never stores or reads it. The API is the origin hosting PhoneWeb.
class SessionPlatform {
  String get clientKind => 'web';

  String get platform => 'web';

  Uri? get defaultServer => Uri.parse(web.window.location.origin);

  Future<String?> readServer() async => null;

  Future<void> writeServer(String? server) async {}

  Future<String?> readRefreshToken() async => null;

  Future<void> writeRefreshToken(String? token) async {}

  /// Reads `#handoff=<code>` written by the App and removes it from the URL
  /// (and history) right away, so the code is never reused or shared.
  String? takeHandoffCode() {
    final fragment = Uri.base.fragment;
    if (!fragment.startsWith('handoff=')) return null;
    final code = Uri.decodeComponent(fragment.substring('handoff='.length));
    final clean = Uri.base.replace(fragment: '').toString().replaceAll('#', '');
    web.window.history.replaceState(null, '', clean);
    return code.isEmpty ? null : code;
  }
}
