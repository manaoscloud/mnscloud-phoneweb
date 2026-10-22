# Security

PhoneWeb must protect local account credentials and avoid leaking provider or
customer information.

## Storage Strategy

Account metadata:

- local database or local preferences
- no password fields
- no TURN password fields

Secrets (`lib/src/storage/account_secret_store*.dart`):

- native builds (Android, iOS, macOS, Windows, Linux): `flutter_secure_storage`
  (operating system keychain/keystore)
- web/PWA: AES-GCM ciphertext in `localStorage`
  (`mnscloud_phoneweb.secret.v1.<account_id>`), encrypted with a
  **non-extractable** WebCrypto key kept only in IndexedDB
  (`mnscloud_phoneweb_keys`); without WebCrypto or IndexedDB the password stays
  in memory and must be typed again after a reload
- one secret entry per account and secret type
- delete secrets when an account is removed
- records saved by releases before v0.1.61 kept the password inside the account
  JSON; the first load moves it into the secret store and rewrites the record
  without it

The web protection covers stored data at rest (disk, profile copies, storage
dumps). Script running inside the PhoneWeb origin can still use the key, so the
usual XSS defenses remain mandatory.

Example secret keys:

```text
account:<account_id>:sip_password
account:<account_id>:turn_password
```

## Transport Security

Production providers should use:

- WSS, not plain WS
- valid TLS certificates
- DTLS-SRTP media
- TURN over TLS where possible

The UI may allow local/lab exceptions in developer mode, but production examples
must recommend secure defaults.

## Log Redaction

Never log:

- SIP passwords
- TURN passwords
- Authorization headers
- SIP digest response
- full provider tokens
- private IP topology from user reports unless explicitly sanitized

Recommended redaction:

```text
password=<redacted>
Authorization: <redacted>
turnPassword=<redacted>
```

## Future PIN / Biometrics

Future app lock can use:

- PIN
- biometrics through platform APIs
- automatic lock timeout

App lock is a local UX/security feature. It does not replace provider-side SIP
authentication or device security.

## Export / Import

Future export/import must:

- be optional
- encrypt exported secrets with a user-provided passphrase
- never export plaintext passwords
- clearly warn users before sharing exported files

## Public Repository Rules

Do not commit:

- real credentials
- customer screenshots with visible numbers/domains
- production WSS endpoints unless intentionally public
- crash logs with credentials
- private provider configs


## Contact-center authorization

Agent commands use the in-memory PhoneWeb access token and a revision checked by the API. The API resolves tenant, phone identity, line ownership and commercial access; the client cannot assert them. Call and wrap-up states come only from the authenticated PBX runtime. Contact notes are restricted to the session that handled the contact and are never stored in local browser persistence. SSE uses an Authorization header, never a token in its URL, and reconnects with the durable event cursor. The server closes streams when authentication or commercial access expires.
