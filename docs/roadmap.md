# Roadmap

## Phase 0: Repository And Documentation

- Public repository governance.
- Architecture docs.
- Security docs.
- CI baseline.
- Flutter skeleton.

## Phase 1: WebRTC MVP

- Manual WebRTC account CRUD.
- Secure password storage.
- SIP over WSS registration with `sip_ua`.
- Multiple accounts registered simultaneously.
- Outgoing calls.
- Incoming calls while app is running.
- Answer, reject, hang up.
- Mute, hold, DTMF, speaker route where supported.
- Local call history.
- Basic diagnostics.

## Phase 2: Provider Diagnostics

- WSS connectivity test.
- STUN/TURN validation.
- Registration failure classification.
- ICE state visibility.
- Sanitized diagnostic export.
- Provider setup examples for Asterisk and FreeSWITCH.

## Phase 3: Mobile Calling UX

- Android calling UX research and integration.
- iOS calling UX research and integration.
- Optional FCM/APNs push adapter design.
- Clear documentation for closed-app incoming call requirements.

## Phase 4: SDK And White-Label

- Split packages.
- Headless core package.
- Reusable UI package.
- White-label configuration.
- Example external integration app.

## Phase 5: Optional Traditional SIP Review

Traditional SIP is intentionally out of scope now. A future review may evaluate:

- native SIP engine package
- Linphone SDK licensing
- PJSIP licensing
- native plugin maintenance
- platform distribution implications

Traditional SIP must remain optional and separate from the WebRTC core.

