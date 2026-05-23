# MNSCloud PhoneWeb Skill

Use this skill when working on the standalone MNSCloud PhoneWeb repository.

## Purpose

PhoneWeb is a public Flutter WebRTC softphone. The initial product supports
manual WebRTC account configuration through SIP over secure WebSocket. It does
not require an MNSCloud login, a proprietary backend, Linphone SDK, PJSIP, or
traditional SIP transports.

## Public Repository Rules

- Do not commit secrets, passwords, TURN credentials, real customer data,
  private domains, production IPs, provider credentials, signing keys, or
  private topology.
- Use safe examples such as `pbx.example.com`, `wss://pbx.example.com/ws`,
  `stun:stun.example.com:3478`, and `<password>`.
- Never log raw credentials, SIP digest material, authorization headers, or TURN
  shared secrets.
- Keep all docs, examples, comments, and commit messages in English.

## Architecture Rules

- Use clean boundaries: `presentation`, `application`, `domain`, and
  `infrastructure`.
- Keep modules separated: account, voip, call, call history, settings, audio,
  diagnostics, and shared utilities.
- The domain layer must not import Flutter UI or `sip_ua`.
- The application layer orchestrates use cases but does not know storage or UI
  details.
- Infrastructure owns `sip_ua`, `flutter_webrtc`, secure storage, local storage,
  platform permissions, and diagnostics adapters.
- Keep a `VoipEngine` abstraction even while only one WebRTC engine exists.
- Traditional SIP engines must be optional future packages, not hardwired into
  the WebRTC app.

## Validation

```bash
flutter pub get
flutter analyze
flutter test
```

For documentation-only changes, at minimum review Markdown links and run
available formatting or lint checks.

## Maintainer Workflow

After completed changes, validate, commit, and push to the GitHub remote. If a
change spans the workspace registry or documentation, commit and push those
changes separately in the root workspace repository.

