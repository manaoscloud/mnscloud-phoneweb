# Contributing To MNSCloud PhoneWeb

Thank you for your interest in contributing to MNSCloud PhoneWeb.

PhoneWeb is a public Flutter WebRTC softphone maintained so customers, partners,
and community contributors can inspect, reuse, improve, and integrate it.

## Contribution Model

All contributions must go through a Pull Request. Direct pushes to `main` are
not part of the external contribution workflow.

Recommended flow:

```bash
git checkout -b feature/clear-change-name
flutter pub get
# make changes
flutter analyze
flutter test
git commit -m "Describe the change clearly"
git push origin feature/clear-change-name
```

Then open a Pull Request against `main`.

## Review And Acceptance

MNSCloud maintainers review contributions for:

- WebRTC provider compatibility
- platform safety across Android, iOS, Web, Windows, macOS, and Linux
- security and credential handling
- architectural boundaries
- code quality and test coverage
- documentation quality
- long-term SDK and white-label readiness

A contribution may be accepted, changed, postponed, or declined at the sole
discretion of MNSCloud maintainers.

## Security Rules

Never commit or expose:

- SIP passwords
- TURN usernames or passwords
- real provider credentials
- customer data
- production-only domains or IP addresses
- private topology
- API tokens
- signing keys
- hidden bypasses

Use placeholders in docs, tests, screenshots, and examples.

## Product Scope

The initial scope is WebRTC/SIP over WSS only. Do not add traditional SIP over
UDP, TCP, or TLS, Linphone SDK, or PJSIP to the core repository without an
approved design and licensing review.

## Pull Request Expectations

A good Pull Request includes:

- summary of what changed and why
- validation commands and results
- screenshots for UI changes
- notes for platform-specific behavior
- dependency impact
- security impact
- limitations or follow-up work

## Paid Contributions

MNSCloud may choose to pay, sponsor, contract, or hire contributors whose work
demonstrates strong value. Opening a Pull Request does not create a payment
obligation. Paid work requires explicit written agreement with MNSCloud.

