# Security Policy

MNSCloud PhoneWeb is a public softphone repository. It must never contain
permanent secrets, customer data, real provider credentials, production-only
domains or IP addresses, private infrastructure topology, or internal MNSCloud
business rules.

## Responsibility Split

PhoneWeb stores user-configured accounts locally on the user's device. The app
does not provide backend authorization, tenant enforcement, billing policy, or
provider-side account ownership validation.

The user or provider is responsible for:

- SIP/WebRTC account validity
- WSS endpoint configuration
- TLS certificates
- STUN/TURN infrastructure
- PBX/provider security
- provider-side call permissions and billing

PhoneWeb is responsible for:

- protecting locally stored credentials
- avoiding credential leaks in logs
- using secure transports when configured
- exposing clear diagnostics without secrets
- documenting platform limitations honestly

## Credential Handling

- Store account passwords through secure device storage.
- Store TURN secrets through secure device storage when supported.
- Never write raw credentials to logs, crash reports, screenshots, issue
  templates, or examples.
- Keep account metadata separate from account secrets.
- Prepare future export/import features to use user-provided encryption.

## Reporting Vulnerabilities

Please report vulnerabilities privately to MNSCloud maintainers. Do not open
public issues containing exploit details, credentials, or customer-identifying
data.

## Public Issue Safety

When opening public issues, redact:

- usernames if they identify real customers
- domains if they are not intentionally public
- IP addresses
- credentials
- SIP Authorization headers
- TURN credentials
- call IDs that expose customer information

