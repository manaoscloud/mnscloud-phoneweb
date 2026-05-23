# Diagnostics

PhoneWeb should provide useful troubleshooting data without exposing secrets.

## Diagnostic Goals

- explain registration failures
- explain WebSocket connectivity issues
- explain ICE/media failures
- help providers verify WebRTC compatibility
- help contributors reproduce bugs safely

## Events To Capture

- app version and platform
- account ID, not password
- WSS connection state
- SIP registration state
- call state transitions
- ICE connection state
- selected codec, when available
- microphone permission state
- sanitized error messages

## Ring Buffer

Use a bounded in-memory or local ring buffer:

```text
max entries: 1000
max retention: configurable
export: manual only
```

## Redaction Rules

Redact:

- passwords
- TURN credentials
- SIP Authorization
- tokens
- full internal provider payloads

## Export

Diagnostic export should produce a text or JSON file with:

- platform
- app version
- package version
- sanitized account metadata
- recent events
- current registration status
- call failure reason, if any

The export UI must remind users to review logs before sharing.

