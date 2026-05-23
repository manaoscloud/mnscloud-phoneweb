# SDK And Modularization Strategy

PhoneWeb starts as a standalone Flutter app but is designed to become reusable.

## Stage 1: Single App With Clean Internal Boundaries

Initial layout:

```text
lib/src/account/
lib/src/voip/
lib/src/call/
lib/src/call_history/
lib/src/settings/
lib/src/audio/
lib/src/diagnostics/
lib/src/shared/
```

This is easier for early development while keeping module boundaries clear.

## Stage 2: Package Split

Future package layout:

```text
packages/
  phoneweb_core/
  phoneweb_ui/
  phoneweb_sip_ua/
  phoneweb_storage/
  phoneweb_diagnostics/
apps/
  phoneweb_app/
```

## Stage 3: SDK Mode

SDK consumers should be able to embed:

- account management UI
- dialer UI
- incoming call UI
- call controls
- diagnostics screen
- or only the headless call engine

## Plugin-Friendly Design

Use contracts:

```dart
abstract class VoipEngine {}
abstract class AccountRepository {}
abstract class CredentialStore {}
abstract class CallHistoryRepository {}
abstract class DiagnosticsSink {}
```

External apps can replace infrastructure implementations without changing core
domain logic.

## Git Submodule Use

As a submodule:

```bash
git submodule add https://github.com/manaoscloud/mnscloud-phoneweb.git vendor/mnscloud-phoneweb
```

Consumers can either run the app directly or import selected packages once the
repository is split.

## Monorepo Use

As a monorepo module:

```text
apps/
  customer_app/
modules/
  mnscloud-phoneweb/
```

Keep package dependencies explicit and avoid relying on files outside this
repository.

## White-Label Use

Future white-label configuration may include:

- app name
- icons
- theme
- default WSS domain templates
- help links
- support URL
- optional provider presets

White-label defaults must not include real credentials.

