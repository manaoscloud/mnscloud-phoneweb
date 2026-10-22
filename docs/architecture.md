# Architecture

MNSCloud PhoneWeb uses a clean, modular Flutter architecture. The goal is to
keep WebRTC calling, account storage, call orchestration, diagnostics, and UI
independent from each other.

The first implementation supports only WebRTC through SIP over secure WebSocket.
The architecture still keeps a `VoipEngine` abstraction so future engines can be
added without rewriting the app.

## Goals

- Run as a standalone app.
- Work without MNSCloud login or backend provisioning.
- Support manually configured WebRTC accounts.
- Keep credentials local to the user's device.
- Keep UI independent from SIP/WebRTC implementation details.
- Prepare future SDK, package, submodule, monorepo, and white-label use.
- Avoid traditional SIP licensing concerns in the initial scope.

## Layers

```text
presentation
  Flutter screens, widgets, controllers, view models

application
  use cases and orchestration

domain
  entities, value objects, repository contracts, engine contracts, events

infrastructure
  sip_ua adapter, flutter_webrtc adapter, secure storage, local database,
  native contacts adapter, permission adapters, diagnostics adapters
```

## Dependency Direction

```text
presentation -> application -> domain
infrastructure -> domain
application -> domain
```

The domain layer must not import Flutter widgets, `sip_ua`, `flutter_webrtc`,
local storage packages, or platform plugins.

## Modules

```text
account
  Account model, account repository, credential store, account list UI.

voip
  VoipEngine contract, SipUaWebRtcEngine adapter, registration state.

call
  Call session model, call actions, incoming/outgoing call orchestration.

call_history
  Local call history entities and persistence.

contacts
  Local contact model, native address book repository, platform permission
  handling, and UI sync actions. Android, iOS, and macOS use
  `flutter_contacts`; Web returns an explicit unsupported result because
  browsers do not expose the operating system address book.

settings
  App preferences and future white-label/runtime settings.

audio
  Microphone permission, audio route, speaker, mute, and platform constraints.

diagnostics
  Sanitized logs, registration diagnostics, WebRTC state, export support.

shared
  Common result types, IDs, clocks, validation, and utility contracts.
```

## Runtime Diagram

```text
Account Screen
  |
  v
AccountController
  |
  v
CreateAccount / UpdateAccount / RemoveAccount use cases
  |
  +--> AccountRepository
  +--> CredentialStore

Dialer Screen
  |
  v
CallController
  |
  v
PlaceCall use case
  |
  v
VoipEngine
  |
  v
SipUaWebRtcEngine
  |
  +--> sip_ua
  +--> flutter_webrtc

Contacts Screen
  |
  v
NativeContactsRepository
  |
  +--> flutter_contacts on Android, iOS, macOS
  +--> unsupported adapter on Web, Windows, Linux
```

## Engine Abstraction

The app initially ships one concrete engine:

```text
SipUaWebRtcEngine
```

It handles:

- WebSocket connection through `sip_ua`
- SIP REGISTER over WSS
- INVITE, answer, reject, BYE
- DTMF where supported
- hold/mute mapping
- registration events
- call events

Future optional engines must live in separate packages, for example:

```text
softphone_native_sip
softphone_linphone
softphone_pjsip
```

Those packages must not become mandatory dependencies of the WebRTC-only app.

## State Management

The recommended state approach is Riverpod or BLoC. The important rule is not
the library itself, but the boundary:

- UI observes application state.
- Use cases mutate state through repositories and services.
- Infrastructure emits raw events that are normalized before reaching UI.

## Account Sessions

Each enabled account owns a registration session:

```text
accountId -> RegistrationSession -> VoipEngine registration handle
```

Multiple accounts can be registered simultaneously. The MVP should allow only
one active call at a time unless a later design explicitly supports concurrent
calls.

## Error Model

Errors should be normalized into domain/application failures:

```text
RegistrationFailed
WebSocketDisconnected
AuthenticationFailed
IceFailed
MicrophonePermissionDenied
CallRejected
CallTimeout
UnsupportedProviderConfiguration
```

Raw plugin errors must be sanitized before display, logging, or export.

## Contact-center agent panel

The shared signed-in session surface embeds `AgentPanel` on desktop, mobile web and installed PWA. The panel authenticates through the in-memory PhoneWeb access token, displays the server state and queue memberships, and sends revision-checked login, pause, available, logout and finish-wrap-up commands. A pause requires a tenant catalog reason. ON_CALL and WRAP_UP can only originate from authenticated PBX events. Another device cannot take over a live agent session.

`AgentApi` uses authenticated fetch SSE (no token in URLs), reconnects with the last event ID and reloads authoritative state. Missed notifications are recovered from the immutable state ledger. The panel renders a wrap-up countdown, and translates controls in PT/EN/ES. `test/agent_panel_test.dart` verifies pause validation and queue exit at 390px and 1280px.

### Contact-center routing profiles and contact notes

Routing profiles (`VoipPabxAgentProfile` / `VoipPabxAgentProfileQueue`) group queues, penalties and ACW seconds. A linked agent uses the profile's effective memberships; direct memberships are ignored while a profile is selected. The App provides the canonical profile CRUD and queue collection with FK quick-create. Queue selection is filtered by tenant and customer ownership in the database. Profile edits affect all linked agents on reconciliation.

Runtime queue snapshots carry only aggregate waiting count/longest wait, never caller identity. Counters become unavailable after 30 seconds without observation. SSE sends authoritative snapshots as well as durable transition IDs; PhoneWeb does not poll queue state. `VoipPabxAgentContact` records a runtime-authenticated agent participation, with optional disposition and spelling-preserving notes. Notes are limited to 4000 characters and revision-checked against the originating phone session.

Agent creation/enabling checks the active entitlement and passes its quota to the tenant-serialized configure routine, which counts enabled phone-linked agents. Standalone resource contracts without a package limit retain the billing system's unlimited quantity semantics. No prices or paid subscriptions are created by the schema seed. Revoked/expired sessions, disabled identities, lost line assignments and released/expired claims leave the routing set; hot-desk stations are cleared.
