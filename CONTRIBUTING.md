# Contributing

Scrivora is open source. Contributions should preserve the local-first privacy
boundary and keep public claims accurate.

## Development Setup

Run the focused checks first:

```bash
swift test
swift build --product LocalVoiceFlowApp
```

Run the app with mock ASR when testing UI or permissions without a model:

```bash
LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp
```

Install a local app bundle:

```bash
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
```

## Contribution Rules

- Keep audio and transcription local unless a feature explicitly documents a
  different data flow.
- Do not commit transcripts, recordings, logs, model caches, app support data,
  signing material, credentials, generated app bundles, zips, or DMGs.
- Add or update focused tests for behavior changes.
- Keep user-facing copy factual and short.
- Separate source-code truth from installed-app truth when reporting results.
- Document any new network access, storage path, helper process, or model
  downloader.

## Before Opening A PR

Run:

```bash
swift test
Scripts/audit_sensitive_files.sh
```

For UI or app behavior changes, also run the app locally and verify the affected
flow in the real macOS app.

## Privacy-Sensitive Changes

Get extra review for changes touching:

- Audio capture.
- Transcript storage.
- Clipboard or paste behavior.
- Redacted export.
- Model downloads.
- Offline Mode.
- App permissions.
- Signing, packaging, notarization, or update manifests.

## Documentation Style

- Prefer direct, concrete language.
- Do not include local machine state or one-off debug logs.
- Do not describe beta scripts as public release infrastructure.
- Do not claim notarization, hosted updates, model redistribution rights, or
  production readiness unless verified.
