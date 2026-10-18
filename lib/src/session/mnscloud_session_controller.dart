import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mnscloud_session_api.dart';
import 'session_platform.dart';

enum MnscloudSessionStatus { signedOut, working, signedIn }

/// Optional MNSCloud sign-in of PhoneWeb. The standalone softphone works
/// without it; when signed in, the access token lives only in memory and is
/// renewed before it expires (docs/security.md).
class MnscloudSessionController extends ChangeNotifier {
  MnscloudSessionController({
    SessionPlatform? platform,
    MnscloudSessionApi Function(Uri server)? apiFactory,
  }) : _platform = platform ?? SessionPlatform(),
       _apiFactory =
           apiFactory ??
           ((server) => MnscloudSessionApi(baseUrl: _apiRoot(server)));

  final SessionPlatform _platform;
  final MnscloudSessionApi Function(Uri server) _apiFactory;

  MnscloudSessionStatus _status = MnscloudSessionStatus.signedOut;
  MnscloudSessionGrant? _grant;
  Uri? _server;
  String? _errorCode;
  String? _errorMessage;
  List<MnscloudTenantChoice> _tenantChoices = const [];
  Timer? _refreshTimer;

  MnscloudSessionStatus get status => _status;
  MnscloudSessionGrant? get session => _grant;
  bool get signedIn =>
      _status == MnscloudSessionStatus.signedIn && _grant != null;
  Uri? get server => _server;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;
  List<MnscloudTenantChoice> get tenantChoices => _tenantChoices;

  /// Whether the user must type the server URL (native builds).
  bool get needsServer => _platform.defaultServer == null;

  /// Bearer token for MNSCloud PhoneWeb API calls, or null when signed out.
  String? get accessToken => signedIn ? _grant!.accessToken : null;

  static Uri _apiRoot(Uri server) {
    final base = server.replace(
      path: server.path.endsWith('/') ? server.path : '${server.path}/',
    );
    return base.resolve('api/v1/');
  }

  /// On start: an App handoff code wins; otherwise resume an existing session.
  Future<void> restore() async {
    _server =
        _platform.defaultServer ?? _parseServer(await _platform.readServer());
    final code = _platform.takeHandoffCode();
    if (code != null && _server != null) {
      await _run(
        () => _api.exchange(
          code: code,
          clientKind: _platform.clientKind,
          platform: _platform.platform,
        ),
      );
      return;
    }
    if (_server == null) return;
    final stored = await _platform.readRefreshToken();
    if (_platform.clientKind == 'native' && stored == null) return;
    await _run(() => _api.refresh(stored), quiet: true);
  }

  Future<bool> signIn({
    required String identifier,
    required String password,
    String? server,
    String? tenantUUID,
    String? deviceName,
  }) async {
    if (needsServer) {
      final parsed = _parseServer(server);
      if (parsed == null) {
        _fail(
          'SERVER_INVALID',
          'Informe o endereço do servidor MNSCloud (https://...).',
        );
        return false;
      }
      _server = parsed;
      await _platform.writeServer(parsed.toString());
    }
    return _run(
      () => _api.signIn(
        identifier: identifier.trim(),
        password: password,
        clientKind: _platform.clientKind,
        tenantUUID: tenantUUID,
        deviceName: deviceName,
        platform: _platform.platform,
      ),
    );
  }

  Future<void> signOut() async {
    final token = _grant?.accessToken;
    _refreshTimer?.cancel();
    _grant = null;
    _status = MnscloudSessionStatus.signedOut;
    _tenantChoices = const [];
    notifyListeners();
    await _platform.writeRefreshToken(null);
    if (token != null && _server != null) await _api.signOut(token);
  }

  MnscloudSessionApi get _api => _apiFactory(_server!);

  Future<bool> _run(
    Future<MnscloudSessionGrant> Function() call, {
    bool quiet = false,
  }) async {
    _status = MnscloudSessionStatus.working;
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();
    try {
      _accept(await call());
      return true;
    } on MnscloudApiException catch (error) {
      _grant = null;
      _status = MnscloudSessionStatus.signedOut;
      _tenantChoices = error.tenants;
      if (error.status == 401) await _platform.writeRefreshToken(null);
      if (!quiet) {
        _errorCode = error.code;
        _errorMessage = _messageFor(error);
      }
      notifyListeners();
      return false;
    }
  }

  void _accept(MnscloudSessionGrant grant) {
    _grant = grant;
    _status = MnscloudSessionStatus.signedIn;
    _tenantChoices = const [];
    unawaited(_platform.writeRefreshToken(grant.refreshToken));
    _scheduleRefresh(grant.expiresIn);
    notifyListeners();
  }

  void _scheduleRefresh(Duration expiresIn) {
    _refreshTimer?.cancel();
    final lead = expiresIn.inSeconds > 120
        ? const Duration(seconds: 60)
        : Duration.zero;
    _refreshTimer = Timer(expiresIn - lead, () async {
      final stored = await _platform.readRefreshToken();
      await _run(() => _api.refresh(stored), quiet: true);
    });
  }

  void _fail(String code, String message) {
    _errorCode = code;
    _errorMessage = message;
    _status = MnscloudSessionStatus.signedOut;
    notifyListeners();
  }

  Uri? _parseServer(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty || uri.scheme != 'https') return null;
    return uri.replace(path: '', query: null, fragment: null);
  }

  String _messageFor(MnscloudApiException error) {
    return switch (error.code) {
      'PHONE_INVALID_CREDENTIALS' => 'Usuário ou senha inválidos.',
      'PHONE_TENANT_SELECTION_REQUIRED' =>
        'Este login tem PhoneWeb em mais de uma empresa. Escolha uma.',
      'PHONE_ACCESS_DENIED' =>
        'Este login não tem acesso ao PhoneWeb. Fale com o administrador.',
      'PHONE_USE_APP_SIGNIN' =>
        'Entre no App MNSCloud e abra o PhoneWeb a partir dele.',
      'PHONE_PASSWORD_CHANGE_REQUIRED' =>
        'Troque a senha temporária (no Pulse ou no portal do cliente) antes de entrar.',
      'PHONE_ACCOUNT_LOCKED' =>
        'Conta bloqueada temporariamente. Tente mais tarde.',
      'PHONE_HANDOFF_INVALID' =>
        'O link de entrada expirou. Abra o PhoneWeb pelo App novamente.',
      'COMMERCIAL_ENTITLEMENT_REQUIRED' =>
        'O PhoneWeb não está incluído na assinatura da empresa.',
      'NETWORK_ERROR' => 'Não foi possível acessar o servidor MNSCloud.',
      _ => 'Não foi possível entrar. Tente novamente.',
    };
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
