# Call Flows

This document describes the main registration and call flows for the WebRTC-only
PhoneWeb MVP.

## Registration Flow

```text
App starts
  |
  v
Load local accounts
  |
  v
For each enabled + autoRegister account
  |
  v
Read password from secure storage
  |
  v
Create SIP UA settings
  |
  v
Start WebSocket/WSS session
  |
  v
Send SIP REGISTER
  |
  +-- success -> registered
  +-- failure -> failed + retry policy
```

Pseudocode:

```dart
for (final account in accounts.where((a) => a.enabled && a.autoRegister)) {
  final password = await credentialStore.readPassword(account.id);
  if (password == null) {
    registrationBus.failed(account.id, MissingCredentialFailure());
    continue;
  }

  await voipEngine.registerAccount(account, password);
}
```

## Outgoing Call Flow

```text
User selects account
  |
  v
User enters destination
  |
  v
Validate account is registered
  |
  v
Request microphone permission
  |
  v
Create call session
  |
  v
Send INVITE through SIP over WSS
  |
  v
WebRTC media negotiation
  |
  +-- connected -> active call UI
  +-- failed -> error + call history entry
```

Pseudocode:

```dart
final permission = await audioPermissions.ensureMicrophone();
if (!permission.granted) {
  throw MicrophonePermissionDenied();
}

final call = await voipEngine.call(
  accountId: selectedAccountId,
  destination: normalizedDestination,
);

callHistory.recordOutgoingStarted(call);
```

## Incoming Call Flow

Foreground or running app:

```text
Registered account receives INVITE
  |
  v
SipUaWebRtcEngine emits IncomingCallEvent
  |
  v
Application creates CallSession
  |
  v
UI shows incoming call screen
  |
  +-- answer -> accept call
  +-- reject -> reject call
```

Pseudocode:

```dart
voipEngine.callEvents.listen((event) {
  if (event is IncomingCallEvent) {
    incomingCallController.show(event.callSession);
  }
});
```

## Hangup Flow

```text
User taps hang up
  |
  v
CallController requests hangup
  |
  v
VoipEngine sends BYE or CANCEL
  |
  v
CallSession transitions to ended
  |
  v
Call history entry is finalized
```

## Multiple Accounts

Each account has independent registration state:

```text
account A -> registered
account B -> failed
account C -> offline
```

Call events must always include:

- account ID
- call ID
- direction
- remote identity
- call state

The MVP should support multiple registered accounts but one active media call at
a time. Future work may add call waiting or multiple concurrent calls.

## Reconnection

Recommended initial strategy:

```text
WebSocket disconnected
  |
  v
set account status = offline/reconnecting
  |
  v
retry with exponential backoff
  |
  +-- success -> registered
  +-- max retry window -> failed
```

Retry must be per account. One failing provider must not break other accounts.

