# Provider Compatibility

PhoneWeb supports WebRTC providers that expose SIP over secure WebSocket.

## Required Provider Capabilities

- SIP over WebSocket or secure WebSocket
- WebRTC-compatible media negotiation
- DTLS-SRTP
- ICE
- codec support compatible with browser/mobile WebRTC stacks
- reachable WSS URL
- valid TLS certificate for production

## Asterisk

Asterisk can work when configured with:

- PJSIP transport for WSS
- HTTP/WebSocket enabled
- DTLS-SRTP
- ICE support
- WebRTC endpoint settings
- proper codecs, usually Opus/PCMU/PCMA depending on deployment

## FreeSWITCH

FreeSWITCH can work when configured with:

- WebSocket/WSS SIP profile
- TLS certificate
- WebRTC media profile
- ICE/STUN/TURN as needed
- compatible codec configuration

## Kamailio / OpenSIPS

Kamailio or OpenSIPS can act as a WebRTC edge in front of PBX servers. Typical
roles:

- terminate or proxy SIP over WebSocket
- normalize SIP headers
- route by domain
- integrate with RTP media relay when bridging WebRTC and traditional RTP

## Hosted Providers

Hosted providers must publish WebRTC settings. A generic SIP hostname and port
5060/5061 is not enough for the initial PhoneWeb scope.

Required user-facing provider details:

```text
SIP username
SIP password
SIP domain
WSS URL
STUN/TURN details when required
```

## Unsupported In Initial Scope

- SIP UDP
- SIP TCP
- SIP TLS without WebSocket
- IAX
- proprietary softphone protocols
- providers requiring a closed-source native SDK

