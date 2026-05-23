# MNSCloud PhoneWeb

MNSCloud PhoneWeb is a public, standalone Flutter softphone focused on
WebRTC-based calling through SIP over secure WebSocket.

The project is intentionally backend-independent at the application level:
users can manually configure WebRTC accounts from public or private providers
without using an MNSCloud login, REST API, or proprietary provisioning service.

PhoneWeb is designed to be reusable as:

- a standalone Flutter app
- a Git submodule
- a private or public package dependency
- a monorepo module
- a future white-label app
- a future SDK-style integration layer

## Scope

Initial scope:

- WebRTC softphone for SIP over WebSocket/WSS
- manual account configuration
- multiple WebRTC accounts
- account registration and unregister
- outgoing calls
- incoming calls while the app is running
- answer, reject, hang up
- mute, hold, DTMF, speaker route where supported
- local call history
- secure credential storage
- diagnostics and sanitized logs

Out of scope for the initial public version:

- traditional SIP over UDP, TCP, or TLS without WebSocket
- Linphone SDK
- PJSIP
- proprietary backend provisioning
- guaranteed closed-app incoming calls without push infrastructure
- storing provider secrets outside the user's device

Traditional SIP may be added in the future as a separate optional native engine
package, after licensing and distribution requirements are reviewed.

## Target Platforms

Planned Flutter targets:

- Android
- iOS
- Web
- Windows
- macOS
- Linux

Platform support depends on Flutter, `flutter_webrtc`, `sip_ua`, and each
operating system's media, permission, background execution, and packaging
rules. See [Platform Limitations](docs/platform-limitations.md).

## Recommended Stack

- Flutter
- Dart
- `flutter_webrtc`
- `sip_ua`
- `flutter_secure_storage`
- `permission_handler`
- `go_router`
- Riverpod or BLoC for state management
- Drift or Isar for local call history
- `freezed` and `json_serializable` for immutable models
- local sanitized diagnostics logger

## WebRTC Provider Requirements

A provider must expose SIP over WebSocket/WebRTC. Typical requirements:

- public or reachable WSS endpoint, for example `wss://pbx.example.com/ws`
- valid TLS certificate for WSS
- SIP domain, for example `pbx.example.com`
- extension or SIP username
- password or equivalent SIP credential
- DTLS-SRTP media support
- ICE support
- STUN and TURN where NAT traversal requires it

Compatible server families when configured for WebRTC:

- Asterisk
- FreeSWITCH
- Kamailio
- OpenSIPS
- WebRTC-capable hosted PBX providers

Not compatible in the initial scope:

- SIP providers that only expose `sip.example.com:5060` over UDP
- SIP providers that only expose `5061` TLS without WebSocket
- legacy PBX systems without WebRTC/WSS support

## Repository Layout

```text
mnscloud-phoneweb/
  README.md
  CONTRIBUTING.md
  SECURITY.md
  SKILL.md
  AGENTS.md
  CHANGELOG.md
  LICENSE
  pubspec.yaml
  analysis_options.yaml
  .github/
    CODEOWNERS
    pull_request_template.md
    workflows/
      ci.yml
  docs/
    architecture.md
    account-model.md
    call-flows.md
    platform-limitations.md
    security.md
    diagnostics.md
    provider-compatibility.md
    roadmap.md
    sdk-strategy.md
  lib/
    main.dart
    src/
      account/
      voip/
      call/
      call_history/
      settings/
      audio/
      diagnostics/
      shared/
  test/
```

The initial layout keeps the repository runnable as an app while preserving
clean boundaries that can later be split into Dart/Flutter packages.

## Architecture Summary

```text
Flutter UI
  |
  v
Presentation controllers / view models
  |
  v
Application use cases
  |
  v
Domain interfaces and entities
  |
  v
Infrastructure adapters
  |
  +-- sip_ua WebRTC engine
  +-- flutter_webrtc media layer
  +-- secure credential storage
  +-- local call history
  +-- diagnostics logger
```

See [Architecture](docs/architecture.md) for the complete design.

## Account Example

```text
Account name: Company X
Display name: Support
SIP username: 1001
SIP domain: pbx.example.com
WSS URL: wss://pbx.example.com/ws
STUN: stun:stun.example.com:3478
TURN: turns:turn.example.com:5349
```

Passwords and TURN credentials must be stored through secure device storage and
must never be written to logs, screenshots, examples, or issue reports.

## Development

Install Flutter from the official Flutter documentation and verify your local
toolchain:

```bash
flutter doctor
```

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Run the app:

```bash
flutter run
```

Platform-specific setup is documented in [Platform Limitations](docs/platform-limitations.md).

## Public Repository Boundary

This repository is public and must remain safe for customers, partners, and
external developers.

Never commit:

- real SIP passwords
- TURN credentials
- API tokens
- private keys
- customer data
- production-only domains or IP addresses
- private infrastructure topology
- hidden bypass logic
- MNSCloud internal business rules

Use placeholder examples such as `pbx.example.com`, `wss://pbx.example.com/ws`,
`1001`, and `<password>`.

## Documentation

- [Architecture](docs/architecture.md)
- [Account Model](docs/account-model.md)
- [Call Flows](docs/call-flows.md)
- [Platform Limitations](docs/platform-limitations.md)
- [Security](docs/security.md)
- [Diagnostics](docs/diagnostics.md)
- [Provider Compatibility](docs/provider-compatibility.md)
- [SDK Strategy](docs/sdk-strategy.md)
- [Roadmap](docs/roadmap.md)

