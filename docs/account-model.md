# Account Model

PhoneWeb accounts are configured manually by the user. The initial product
supports only WebRTC accounts using SIP over secure WebSocket.

## Account Fields

Required:

- account name
- display name
- SIP username
- SIP domain
- WSS URL
- password

Optional:

- STUN URL
- TURN URL
- TURN username
- TURN password
- auto register
- enabled/disabled
- notes

## Example

```text
Account name: Company X
Display name: Support
SIP username: 1001
SIP domain: pbx.example.com
WSS URL: wss://pbx.example.com/ws
STUN URL: stun:stun.example.com:3478
TURN URL: turns:turn.example.com:5349
```

## Domain Model Example

```dart
enum RegistrationStatus {
  offline,
  registering,
  registered,
  failed,
}

class WebRtcAccount {
  final String id;
  final String name;
  final String displayName;
  final String username;
  final String domain;
  final String wssUrl;
  final String? stunUrl;
  final String? turnUrl;
  final bool enabled;
  final bool autoRegister;

  const WebRtcAccount({
    required this.id,
    required this.name,
    required this.displayName,
    required this.username,
    required this.domain,
    required this.wssUrl,
    this.stunUrl,
    this.turnUrl,
    required this.enabled,
    required this.autoRegister,
  });
}
```

## Credential Separation

Passwords and TURN credentials must not be stored in the same local record as
the visible account metadata.

```dart
abstract class CredentialStore {
  Future<void> savePassword(String accountId, String password);
  Future<String?> readPassword(String accountId);
  Future<void> deletePassword(String accountId);
}
```

Future credential entries:

```dart
class AccountSecretRef {
  final String accountId;
  final String secretName;

  const AccountSecretRef({
    required this.accountId,
    required this.secretName,
  });
}
```

## Repository Contracts

```dart
abstract class AccountRepository {
  Future<List<WebRtcAccount>> listAccounts();
  Future<WebRtcAccount?> getAccount(String accountId);
  Future<void> saveAccount(WebRtcAccount account);
  Future<void> removeAccount(String accountId);
}
```

## Validation Rules

- WSS URL should use `wss://` for production.
- SIP domain must not include a URL scheme.
- Username must not be empty.
- Password must be stored only through `CredentialStore`.
- STUN should start with `stun:` or `stuns:`.
- TURN should start with `turn:` or `turns:`.
- Logs and validation errors must not echo passwords or TURN credentials.

## MNSCloud Sign-in (optional)

Settings › MNSCloud signs in with an identity the user already has in MNSCloud
(App e-mail, Pulse login code or customer portal login). PhoneWeb keeps no
password of its own:

- web/PWA: the API is the origin that hosts PhoneWeb; the refresh token is an
  HttpOnly cookie the app never reads; `#handoff=<code>` from the App signs in
  without typing the password and is removed from the URL at once;
- native builds: the user types the MNSCloud server (`https` only) and the
  refresh token is kept in the OS keychain/keystore;
- the access token lives only in memory and is renewed before it expires.

Signing in never changes manual accounts. Company lines (assigned to the user
or taken from the free-lines pool) appear as read-only "MNSCloud · …" accounts:
their SIP secret and ICE servers come from the API registration bundle and live
only in memory. TURN entries carry short-lived REST credentials; PhoneWeb fetches
a new bundle in the last hour before `iceExpiresAt` and applies it to the next
call without a new REGISTER.

## Future Provisioning

Manual configuration is the default. Future provisioning may be added through:

- encrypted import file
- QR code
- external app link
- white-label bundled defaults
- optional provider API adapter

Provisioning must remain optional. The standalone manual flow must continue to
work without a backend.


## Contact-center station

Agent identity belongs to the signed-in phone user, independently of the manual SIP accounts. The administrator configures a fixed station or permits hot desking. Joining queues selects an assigned PABX line or a line claimed by the current session; softswitch and manual accounts cannot become contact-center stations. A routing profile supplies queue memberships, penalties and after-call work durations. Only the session that joined controls that active agent; signing out revokes its routing eligibility.
