# AGENTS.md

This repository is a standalone public MNSCloud Flutter client.

## Repository

- Name: `mnscloud-phoneweb`
- Product: MNSCloud PhoneWeb
- Type: public WebRTC softphone app
- Initial scope: SIP over secure WebSocket/WebRTC only
- Public boundary: no private MNSCloud platform authority, no secrets, no customer data

## Language

All repository code comments, documentation, examples, commit messages, and
public-facing text must be written in English.

## Contribution Workflow

- Contributions must use Pull Requests.
- Follow `CONTRIBUTING.md`, `SECURITY.md`, and `SKILL.md`.
- Run repository validation before committing.
- Maintainers should commit and push completed changes.

## Architecture Rules

- Keep the app backend-independent.
- Keep credentials on the user's device through secure storage.
- Keep SIP/WebRTC logic behind domain interfaces.
- Keep UI independent from the concrete `sip_ua` implementation.
- Do not add Linphone SDK, PJSIP, or traditional SIP support to the core app
  without a separate design and licensing review.
- Do not make push notifications a hard requirement for manual foreground use.

## Multiplatform UI and behavior contract

- Every PhoneWeb functional or visual change must be implemented and validated
  across desktop, mobile responsive web, and installed PWA layouts.
- Desktop-only changes are not complete unless the same capability is available
  on mobile/PWA or the limitation is explicitly documented before delivery.
- Mobile/PWA must expose the same account, registration diagnostic, call,
  hangup, debug, contact, history, message, version, and settings controls as
  desktop, adapted only for layout density and platform constraints.
- When a feature depends on platform APIs, keep the shared behavior consistent
  and isolate platform-specific differences behind adapters or documented
  fallbacks.
- Before marking a PhoneWeb UI change complete, validate at least one desktop
  width and one mobile/PWA-width layout for visibility, scrolling, tap targets,
  and action parity.

## Security Boundary

Never commit secrets, tokens, customer data, provider credentials, production
domains/IPs, private topology, master keys, hidden bypasses, or private business
rules.

Examples must use placeholders such as `pbx.example.com`, `wss://pbx.example.com/ws`,
`1001`, and `<password>`.

## Validation

Run the relevant checks before opening a Pull Request:

```bash
flutter pub get
flutter analyze
flutter test
```

If Flutter is not available in the environment, document that clearly in the
Pull Request validation section.
