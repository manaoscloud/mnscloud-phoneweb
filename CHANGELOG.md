# Changelog

All notable changes to MNSCloud PhoneWeb will be documented in this file.

The format follows a simple chronological structure. This repository is in the
initial planning and scaffolding phase.

## Unreleased

- Changed unexpected SIP unregistration events to show a retrying
  registration interruption instead of a manual stopped/offline state.
- Added safe SIP registration diagnostics with user-facing failure reasons,
  retry hints, and sanitized copy output.
- Added registration diagnostic details to desktop and mobile account views.
- Fixed incoming WebRTC calls staying in progress without answer/decline
  controls.
- Fixed active call controls so incoming ringing calls show Answer/Decline
  while established calls show Mute/Hold/Hang up.
- Added public repository documentation and architecture baseline.
- Defined WebRTC-only initial scope.
- Excluded traditional SIP, Linphone SDK, and PJSIP from the initial product.
