enum RegistrationStatus {
  offline,
  registering,
  registered,
  failed;

  String get label {
    return switch (this) {
      RegistrationStatus.offline => 'Offline',
      RegistrationStatus.registering => 'Registering',
      RegistrationStatus.registered => 'Registered',
      RegistrationStatus.failed => 'Failed',
    };
  }
}

enum RegistrationDiagnosticSeverity { info, warning, error }

class RegistrationDiagnostic {
  const RegistrationDiagnostic({
    required this.code,
    required this.title,
    required this.detail,
    required this.severity,
    required this.observedAt,
    this.statusCode,
    this.reasonPhrase,
    this.retrying = false,
  });

  final String code;
  final String title;
  final String detail;
  final RegistrationDiagnosticSeverity severity;
  final DateTime observedAt;
  final int? statusCode;
  final String? reasonPhrase;
  final bool retrying;

  String get summary {
    if (statusCode == null) return title;
    return '$statusCode · $title';
  }

  String get copyText {
    final lines = <String>[
      'Registration diagnostic',
      'Code: $code',
      'Severity: ${severity.name}',
      if (statusCode != null) 'SIP status: $statusCode',
      if (reasonPhrase != null && reasonPhrase!.trim().isNotEmpty)
        'Reason: $reasonPhrase',
      'Retrying: ${retrying ? 'yes' : 'no'}',
      'Observed at: ${observedAt.toIso8601String()}',
      'Summary: $title',
      'Detail: $detail',
    ];
    return lines.join('\n');
  }

  static RegistrationDiagnostic registering() {
    return RegistrationDiagnostic(
      code: 'registration_attempt',
      title: 'Registering account',
      detail:
          'PhoneWeb is connecting to the WSS server and sending SIP REGISTER.',
      severity: RegistrationDiagnosticSeverity.info,
      observedAt: DateTime.now(),
      retrying: true,
    );
  }

  static RegistrationDiagnostic registered() {
    return RegistrationDiagnostic(
      code: 'registered',
      title: 'Account registered',
      detail: 'The SIP server accepted the registration.',
      severity: RegistrationDiagnosticSeverity.info,
      observedAt: DateTime.now(),
    );
  }

  static RegistrationDiagnostic stopped() {
    return RegistrationDiagnostic(
      code: 'registration_stopped',
      title: 'Registration stopped',
      detail: 'The account is not currently registered.',
      severity: RegistrationDiagnosticSeverity.info,
      observedAt: DateTime.now(),
    );
  }

  static RegistrationDiagnostic interrupted({
    int? statusCode,
    String? cause,
    String? reasonPhrase,
  }) {
    final normalized = _normalize(cause);
    return RegistrationDiagnostic(
      code: 'registration_interrupted',
      title: 'Registration interrupted',
      detail:
          'The SIP registration was interrupted unexpectedly. PhoneWeb is waiting for the WebSocket/SIP stack to reconnect or refresh the registration.',
      severity: RegistrationDiagnosticSeverity.warning,
      observedAt: DateTime.now(),
      statusCode: statusCode,
      reasonPhrase: _cleanText(reasonPhrase ?? normalized),
      retrying: true,
    );
  }

  static RegistrationDiagnostic fromTransport({
    required String transportState,
    int? statusCode,
    String? cause,
    String? reasonPhrase,
  }) {
    final normalized = _normalize(cause);
    final disconnected = transportState.toLowerCase() == 'disconnected';
    return RegistrationDiagnostic(
      code: disconnected
          ? 'transport_disconnected'
          : 'transport_$transportState',
      title: disconnected
          ? 'WebSocket disconnected'
          : 'Transport $transportState',
      detail: disconnected
          ? 'The WebSocket transport closed before the account completed registration. Check connectivity, WSS URL, TLS certificate, firewall, or server availability.'
          : 'The WebSocket transport changed state while PhoneWeb was registering.',
      severity: disconnected
          ? RegistrationDiagnosticSeverity.warning
          : RegistrationDiagnosticSeverity.info,
      observedAt: DateTime.now(),
      statusCode: statusCode,
      reasonPhrase: _cleanText(reasonPhrase ?? normalized),
      retrying: disconnected,
    );
  }

  static RegistrationDiagnostic fromSipFailure({
    int? statusCode,
    String? cause,
    String? reasonPhrase,
  }) {
    final normalizedCause = _normalize(cause);
    final cleanReason = _cleanText(reasonPhrase ?? normalizedCause);
    final mapped = _mapSipFailure(statusCode, normalizedCause, cleanReason);

    return RegistrationDiagnostic(
      code: mapped.code,
      title: mapped.title,
      detail: mapped.detail,
      severity: mapped.severity,
      observedAt: DateTime.now(),
      statusCode: statusCode,
      reasonPhrase: cleanReason,
      retrying: mapped.retrying,
    );
  }

  static _DiagnosticMap _mapSipFailure(
    int? statusCode,
    String? cause,
    String? reasonPhrase,
  ) {
    final reason = reasonPhrase?.toLowerCase() ?? '';
    return switch (statusCode) {
      401 || 407 => const _DiagnosticMap(
        code: 'sip_auth_challenge_failed',
        title: 'Authentication challenge failed',
        detail:
            'The server requested authentication but the REGISTER did not complete. Verify username, password, SIP domain, and server realm.',
        severity: RegistrationDiagnosticSeverity.error,
      ),
      403 => const _DiagnosticMap(
        code: 'sip_forbidden',
        title: 'Registration forbidden',
        detail:
            'The server rejected this account. Verify that the subscriber is active, authorized, and allowed to register from WebRTC.',
        severity: RegistrationDiagnosticSeverity.error,
      ),
      404 => const _DiagnosticMap(
        code: 'sip_not_found',
        title: 'Account or domain not found',
        detail:
            'The SIP server did not find this user or domain. Verify the SIP username and domain configured in the account.',
        severity: RegistrationDiagnosticSeverity.error,
      ),
      408 => const _DiagnosticMap(
        code: 'sip_timeout',
        title: 'Server did not respond',
        detail:
            'The registration timed out. This is usually temporary; check WSS connectivity, server load, firewall, and routing.',
        severity: RegistrationDiagnosticSeverity.warning,
        retrying: true,
      ),
      423 => const _DiagnosticMap(
        code: 'sip_interval_too_brief',
        title: 'Registration interval too brief',
        detail:
            'The server requested a longer registration interval. PhoneWeb should retry using the server minimum interval.',
        severity: RegistrationDiagnosticSeverity.warning,
        retrying: true,
      ),
      480 || 486 => const _DiagnosticMap(
        code: 'sip_temporarily_unavailable',
        title: 'Server temporarily unavailable',
        detail:
            'The SIP service temporarily refused the registration. Retrying may succeed when the server becomes available.',
        severity: RegistrationDiagnosticSeverity.warning,
        retrying: true,
      ),
      503 when reason.contains('authentication temporarily unavailable') =>
        const _DiagnosticMap(
          code: 'sip_auth_temporarily_unavailable',
          title: 'Authentication temporarily unavailable',
          detail:
              'The SIP server could not validate the account with the realtime authentication service right now. PhoneWeb will retry automatically; check the softswitch/API runtime path if this persists.',
          severity: RegistrationDiagnosticSeverity.warning,
          retrying: true,
        ),
      503 when reason.contains('registration storage unavailable') =>
        const _DiagnosticMap(
          code: 'sip_registration_storage_unavailable',
          title: 'Registration storage unavailable',
          detail:
              'The SIP server authenticated the account but could not save the registration contact. PhoneWeb will retry automatically; check the softswitch location storage/runtime logs.',
          severity: RegistrationDiagnosticSeverity.warning,
          retrying: true,
        ),
      500 || 502 || 503 || 504 => const _DiagnosticMap(
        code: 'sip_server_error',
        title: 'SIP server error',
        detail:
            'The SIP server or an upstream component returned an error. This is usually temporary and should be checked on the server side.',
        severity: RegistrationDiagnosticSeverity.warning,
        retrying: true,
      ),
      _ when cause == 'Connection Error' => const _DiagnosticMap(
        code: 'transport_connection_error',
        title: 'WebSocket connection error',
        detail:
            'PhoneWeb could not keep the WebSocket transport open. Check the WSS URL, TLS certificate, proxy, firewall, or server availability.',
        severity: RegistrationDiagnosticSeverity.warning,
        retrying: true,
      ),
      _ when cause == 'Request Timeout' => const _DiagnosticMap(
        code: 'request_timeout',
        title: 'Registration timed out',
        detail:
            'The server did not answer in time. This is usually temporary; PhoneWeb may register successfully on a later attempt.',
        severity: RegistrationDiagnosticSeverity.warning,
        retrying: true,
      ),
      _ => _DiagnosticMap(
        code: 'registration_failed',
        title: reasonPhrase == null || reasonPhrase.isEmpty
            ? 'Registration failed'
            : reasonPhrase,
        detail:
            'The SIP server rejected or interrupted the registration. Check the account data and server logs if the failure persists.',
        severity: RegistrationDiagnosticSeverity.error,
      ),
    };
  }

  static String? _cleanText(String? value) {
    final clean = value?.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (clean == null || clean.isEmpty) return null;
    return clean.length > 120 ? '${clean.substring(0, 120)}…' : clean;
  }

  static String? _normalize(String? value) {
    final clean = _cleanText(value);
    if (clean == null) return null;
    return clean
        .split('_')
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

class _DiagnosticMap {
  const _DiagnosticMap({
    required this.code,
    required this.title,
    required this.detail,
    required this.severity,
    this.retrying = false,
  });

  final String code;
  final String title;
  final String detail;
  final RegistrationDiagnosticSeverity severity;
  final bool retrying;
}

class WebRtcAccount {
  const WebRtcAccount({
    required this.id,
    required this.name,
    required this.displayName,
    required this.username,
    required this.password,
    required this.domain,
    required this.wssServer,
    required this.stunServer,
    required this.turnServer,
    required this.hasPassword,
    required this.allowInsecureTransport,
    required this.codecPolicy,
    required this.enabled,
    required this.autoRegister,
    required this.status,
    this.diagnostic,
  });

  final String id;
  final String name;
  final String displayName;
  final String username;
  final String password;
  final String domain;
  final String wssServer;
  final String stunServer;
  final String turnServer;
  final bool hasPassword;
  final bool allowInsecureTransport;
  final WebRtcCodecPolicy codecPolicy;
  final bool enabled;
  final bool autoRegister;
  final RegistrationStatus status;
  final RegistrationDiagnostic? diagnostic;

  WebRtcAccount copyWith({
    String? id,
    String? name,
    String? displayName,
    String? username,
    String? password,
    String? domain,
    String? wssServer,
    String? stunServer,
    String? turnServer,
    bool? hasPassword,
    bool? allowInsecureTransport,
    WebRtcCodecPolicy? codecPolicy,
    bool? enabled,
    bool? autoRegister,
    RegistrationStatus? status,
    RegistrationDiagnostic? diagnostic,
  }) {
    return WebRtcAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      wssServer: wssServer ?? this.wssServer,
      stunServer: stunServer ?? this.stunServer,
      turnServer: turnServer ?? this.turnServer,
      hasPassword: hasPassword ?? this.hasPassword,
      allowInsecureTransport:
          allowInsecureTransport ?? this.allowInsecureTransport,
      codecPolicy: codecPolicy ?? this.codecPolicy,
      enabled: enabled ?? this.enabled,
      autoRegister: autoRegister ?? this.autoRegister,
      status: status ?? this.status,
      diagnostic: diagnostic ?? this.diagnostic,
    );
  }
}

enum WebRtcCodecPolicy {
  automaticRecommended,
  opusOnly,
  g711Only;

  String get label {
    return switch (this) {
      WebRtcCodecPolicy.automaticRecommended => 'Automatic recommended',
      WebRtcCodecPolicy.opusOnly => 'OPUS only',
      WebRtcCodecPolicy.g711Only => 'G.711 only',
    };
  }

  String get description {
    return switch (this) {
      WebRtcCodecPolicy.automaticRecommended =>
        'Prefers OPUS and allows PCMU/PCMA fallback for SIP trunks.',
      WebRtcCodecPolicy.opusOnly =>
        'Uses OPUS only. Best for WebRTC-to-WebRTC calls.',
      WebRtcCodecPolicy.g711Only =>
        'Uses PCMU/PCMA only for legacy SIP trunk compatibility.',
    };
  }

  Set<String> get allowedAudioCodecs {
    return switch (this) {
      WebRtcCodecPolicy.automaticRecommended => {'opus', 'pcmu', 'pcma'},
      WebRtcCodecPolicy.opusOnly => {'opus'},
      WebRtcCodecPolicy.g711Only => {'pcmu', 'pcma'},
    };
  }
}
