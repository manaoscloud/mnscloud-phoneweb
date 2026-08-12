# Progressive Web App

PhoneWeb is installable as a Progressive Web App while remaining a standalone
softphone that can be hosted by MNSCloud or by another provider.

## Goals

- Allow users to install PhoneWeb from a supported browser.
- Keep the app backend-independent and provider-neutral.
- Support deployments at the domain root or under a path such as `/phoneweb/`.
- Cache static application assets through Flutter Web's generated service
  worker.
- Keep SIP/WebRTC traffic online-only and always routed through the configured
  WSS, STUN, TURN, and media services.

## Hosting Contract

Production hosting must provide:

- HTTPS with a valid certificate.
- A reachable SIP over WebSocket endpoint, usually `wss://provider.example/ws`.
- The built Flutter files served from the same path used as `--base-href`.
- Correct cache behavior for `index.html` so new releases are discovered.
- Long-lived immutable caching only for fingerprinted static assets.

The manifest intentionally uses relative `id`, `scope`, and `start_url` values.
This keeps the same build portable across root deployments and subpath
deployments when the Flutter `--base-href` matches the hosting path.

## MNSCloud Webapps Build

For the current MNSCloud webapps deployment, build with:

```bash
flutter build web --release --base-href /phoneweb/
```

Then publish the generated `build/web` directory through the webapps runtime.

## Local Root Build

For a provider that hosts PhoneWeb at the domain root:

```bash
flutter build web --release --base-href /
```

## Offline Behavior

The PWA shell can load from cache after the first successful visit, depending on
browser support and cache state. Registration, calls, diagnostics against SIP
servers, and media always require network connectivity.

## Installation Notes

- Chrome and Edge expose an install button when the page is served over HTTPS
  and the manifest/service worker are valid.
- Android browsers usually expose "Install app" or "Add to Home screen".
- iOS Safari supports "Add to Home Screen", but background execution and
  closed-app incoming calls are limited.

## Future Mobile App Boundary

Push notification, reliable closed-app incoming calls, CallKit/ConnectionService
integration, and stronger local credential storage should be implemented in a
future mobile app or native wrapper. They must not become a requirement for
manual foreground PhoneWeb usage.
