# Phone Bridge v1 (App phone dock)

The MNSCloud App hosts PhoneWeb in a same-origin frame (`/phoneweb/?embed=app`) and drives it with
`window.postMessage`. One PhoneWeb code base serves the standalone app, the PWA and the App dock.

## Transport and security

- PhoneWeb enables the bridge only with `?embed=app` inside a frame. It accepts messages only from
  its parent window **and** only when `event.origin` equals its own origin, and it posts only to
  that origin. The App does the same for the frame.
- The edge allows it: the App sends `Permissions-Policy: microphone=(self)` and `/phoneweb/` sends
  `frame-ancestors 'self'` with `microphone=(self)` (mnscloud-agent ThemeDomain vhosts and
  mnscloud-nginx). Any other site cannot frame PhoneWeb.
- No secret, token or SIP credential ever crosses the bridge. Sign-in uses the App handoff
  (`#handoff=<code>`, single use, 60 s); lines and credentials stay inside PhoneWeb.

## Messages

Every message: `{ channel: "mnscloud-phone", v: 1, type, id?, payload? }`. Other channels are
ignored; another `v` gets `UNSUPPORTED_VERSION`.

Commands (App → phone), answered by `{ type: "reply", id, payload: { ok, error? } }`:

| type | payload | errors |
| --- | --- | --- |
| `phone.state` | – | reply payload adds `state` |
| `phone.focus` | – | – |
| `phone.dial` | `{ number }` digits, `+`, `*`, `#` (spaces, `()`, `.`, `-` removed) | `INVALID_NUMBER`, `NOT_REGISTERED`, `CALL_ACTIVE`, `CALL_FAILED` |
| `phone.answer` | – | `NO_INCOMING_CALL` |
| `phone.hangup` | – | `NO_CALL` |
| `phone.mute` | `{ muted }` | `NO_CALL` |
| `phone.dtmf` | `{ tones }` (`0-9*#A-D`) | `INVALID_DTMF`, `NO_CALL` |

Events (phone → App):

| type | payload |
| --- | --- |
| `ready` | `{ version, bridge: 1 }` |
| `state` | `{ signedIn, registration, account, call: null \| { direction, remote, established, answerable, muted } }` (sent on every change) |
| `call.ringing` / `call.started` | `{ direction, remote }` (incoming / outgoing) |
| `call.answered` | `{ direction, remote }` |
| `call.ended` | `{ direction, remote, established, durationMs }` |

Later versions add interaction ids, agent states and transfers (roadmap Q2/P3).
