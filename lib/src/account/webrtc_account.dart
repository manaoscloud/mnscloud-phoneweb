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
    required this.enabled,
    required this.autoRegister,
    required this.status,
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
  final bool enabled;
  final bool autoRegister;
  final RegistrationStatus status;

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
    bool? enabled,
    bool? autoRegister,
    RegistrationStatus? status,
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
      enabled: enabled ?? this.enabled,
      autoRegister: autoRegister ?? this.autoRegister,
      status: status ?? this.status,
    );
  }
}
