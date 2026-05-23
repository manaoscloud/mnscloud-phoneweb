# Security

PhoneWeb must protect local account credentials and avoid leaking provider or
customer information.

## Storage Strategy

Account metadata:

- local database or local preferences
- no password fields
- no TURN password fields

Secrets:

- `flutter_secure_storage`
- one secret entry per account and secret type
- delete secrets when an account is removed

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

