## Summary

Describe what changed and why.

## Release note

<!-- Required: the MNSCloud merge gate refuses a PR without this block (contract: docs/release-notes.md
in the MNSCloud workspace). Keep ONE shape and delete the others:
A) user-visible change: the fields below, short text for the customer in pt-BR, en and es;
   `breaking` also needs action.pt-BR (what the customer must do).
B) another PR of a feature whose text is in a different repository's PR: only
   `feature-key: <task-slug>` and `lead: false`.
C) nothing a user notices (refactor, tests, CI, docs, dependencies): only `visibility: internal`.
Never write server names, IPs, host names, e-mails, paths, credentials, customers or vulnerability
details. -->

```text
visibility: public
feature-key: <task-slug>
lead: true
type: new | improvement | fix | security | breaking | deprecated
audience: tenant | admin | developer
modules: module.<code> | platform
title.pt-BR: <short title for the customer>
title.en: <...>
title.es: <...>
text.pt-BR: <what changed for the customer>
text.en: <...>
text.es: <...>
```

## Type Of Change

- [ ] Bug fix
- [ ] Feature
- [ ] Documentation
- [ ] Refactor
- [ ] Security hardening
- [ ] Platform integration
- [ ] Other

## Validation

Commands run:

```bash
# paste commands here
```

Result:

- [ ] Passed
- [ ] Passed with warnings explained below
- [ ] Not run, reason:

## Security And Public Repository Boundary

- [ ] No secrets, credentials, customer data, private domains/IPs, or private topology were added.
- [ ] Logs and diagnostics do not expose passwords, SIP authorization material, or TURN credentials.
- [ ] Examples use placeholders only.

## Platform Impact

- [ ] Android
- [ ] iOS
- [ ] Web
- [ ] Windows
- [ ] macOS
- [ ] Linux
- [ ] Not applicable

## Multiplatform parity (workspace AGENTS.md → PhoneWeb multiplatform contract)

- [ ] Checked one desktop width and one mobile/PWA width: visibility, scrolling, touch targets and
      the same primary actions (or the limitation is documented in `docs/platform-limitations.md`)

## WebRTC Provider Compatibility

Describe any effect on Asterisk, FreeSWITCH, Kamailio, OpenSIPS, or hosted WebRTC providers.

## Screenshots Or Logs

Add screenshots for UI changes and sanitized logs for calling/registration changes.

## Contributor Note

- [ ] I understand that Pull Requests are reviewed at MNSCloud's discretion.
- [ ] I understand that unpaid Pull Requests do not create a payment obligation unless there is a separate written agreement with MNSCloud.

