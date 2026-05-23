# Platform Limitations

PhoneWeb is Flutter-based and targets Android, iOS, Web, Windows, macOS, and
Linux. WebRTC behavior is not identical across platforms.

## Android

Expected MVP behavior:

- registration while the app is foregrounded
- outgoing calls
- incoming calls while the app is running
- microphone permission
- speaker/mute where supported by platform plugins
- native contact read permission and address book sync

Important limitations:

- app-closed incoming calls are not guaranteed without push infrastructure
- background execution is affected by battery optimization
- persistent WebSocket registration may be suspended by the OS
- reliable production incoming calls usually require FCM plus native calling UI
- the public app reads contacts only after explicit user permission

Future Android work:

- Firebase Cloud Messaging
- foreground service policy review
- self-managed `ConnectionService`
- battery optimization guidance
- native audio route integration

## iOS

Expected MVP behavior:

- foreground registration
- outgoing calls
- incoming calls while the app is active/running
- microphone permission
- native contact read permission and address book sync

Important limitations:

- iOS does not allow arbitrary indefinite background VoIP sockets for modern apps
- closed-app incoming calls require APNs/PushKit and CallKit
- PushKit requires a server capable of sending VoIP pushes
- the initial backend-independent app cannot guarantee closed-app incoming calls
- users may grant limited contact access on newer iOS versions

Future iOS work:

- APNs/PushKit adapter
- CallKit adapter
- optional push gateway integration
- careful App Store policy compliance review

## Web

Expected MVP behavior:

- SIP over WSS
- WebRTC media
- microphone permission through the browser

Important limitations:

- browser requires HTTPS for microphone/WebRTC in production
- no traditional SIP UDP/TCP/TLS
- background behavior depends on browser policies
- audio device selection varies by browser
- push and incoming call UX are browser-dependent
- browsers do not expose the native macOS/iCloud address book to Flutter Web

## Windows, macOS, Linux

Expected MVP behavior:

- WebRTC registration and calls where `flutter_webrtc` supports the platform
- desktop microphone permissions and audio route behavior by operating system
- native macOS contact read permission and address book sync

Important limitations:

- packaging differs per platform
- audio device enumeration and switching can vary
- auto-start/background behavior must be designed per OS
- code signing/notarization may be required for distribution
- Windows and Linux native address book sync are not enabled yet; they can be
  added later through dedicated platform adapters

## Product Statement

The MVP should clearly state:

```text
Incoming calls are supported while the app is running and registered.
Reliable closed-app incoming calls require platform push integrations and a
provider or gateway capable of sending push notifications.
```
