# Security Policy

Scrivora is a local-first macOS app. Core dictation should run without an
account, card, or cloud speech API.

## Supported Scope

Security reports are accepted for the current `main` branch and public release
tags once they exist.

There is no bounty program or guaranteed response SLA yet.

## Reporting

Report security and privacy issues privately to the project owner. Do not open a
public issue for sensitive reports.

Include:

- Short description.
- Steps to reproduce.
- Impact.
- Affected commit, build, or app version.
- Whether local files, transcripts, recordings, credentials, model caches, or
  signing material are exposed.

## In Scope

- Raw audio saved unexpectedly.
- Transcript history saved when privacy settings say it should not be.
- Redacted export leaking transcript text, target app metadata, bundle IDs, or
  local paths.
- Clipboard or paste behavior sending text to the wrong app.
- Offline Mode allowing remote model downloads or remote update checks.
- Update manifest or archive validation bypass.
- Local helper process exposure beyond the intended localhost boundary.
- Secrets, signing material, app support data, logs, recordings, or model caches
  committed to the repo.

## Out Of Scope

- Cloud account security. The current app has no cloud account system.
- Payment or license-key security. Those systems are not part of the current
  app.
- Cloud speech-provider security. The current local transcription path does not
  require a cloud speech provider.

If those systems are added later, update this policy before release.

## Privacy Baseline

Fresh installs should default to Maximum Privacy:

- No raw audio saved.
- No transcript history saved.
- No learning memory saved.
- No analytics.
- No cloud transcription for local dictation.

## Sensitive File Audit

Run:

```bash
Scripts/audit_sensitive_files.sh
```

Expected development signing material belongs only under ignored
`.build/dev-signing`.

## Release Security Gate

Before publishing a public Mac binary:

- Developer ID signing.
- Hardened runtime.
- Notarization.
- Stapling.
- Gatekeeper verification on a clean Mac.
- Clean-Mac permission test.
- Model-license review.
- Sensitive-file audit.
- No live `updates/stable.json` until the exact signed updater ZIP and SHA-256
  exist.

See `RELEASE_STATUS.md` for the current release state.
