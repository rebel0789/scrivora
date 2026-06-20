# Project Status And Roadmap

Use `RELEASE_STATUS.md` for the current release state. This file tracks the
product roadmap and should stay free of local machine state, one-off logs, and
scratch release notes.

## Current Product

Scrivora is a macOS dictation app focused on local transcription and text
insertion into the active app.

Current scope:

- Menu bar app shell.
- Background launch with explicit menu access to the main window.
- Hold Control, double-tap Control, and configurable shortcut triggers.
- Local audio capture, chunking, and VAD.
- FluidAudio Parakeet V2/V3 local transcription support.
- whisper.cpp local fallback downloads.
- Model library with explicit download/delete behavior and missing-model
  fallback.
- Text cleanup profiles.
- Clipboard paste and safe copy fallback.
- Local history, correction memory, privacy controls, and redacted export.
- Website, release notes, update templates, and GitHub workflows.
- Unit tests for core settings, storage, models, cleanup, export, and trigger
  behavior.

## Release Tracks

Source repo:

- Ready to prepare for GitHub publication after the source license is chosen.
- No model weights or release artifacts should be committed.
- Clean clone must pass tests, app build, site staging, and sensitive-file audit.

Mac binary:

- Release scripts exist.
- Public download still requires Developer ID signing, notarization, stapling,
  Gatekeeper verification, and clean-Mac permission tests.

Website:

- Static site is staged with `Scripts/stage_site.sh`.
- `scrivora.me` is the public target.
- Vercel or GitHub Pages deployment should happen only after the repo and domain
  target are confirmed.

## Near-Term Roadmap

1. Choose source license and add `LICENSE`.
2. Finish model and third-party notice review.
3. Run clean-clone build and test.
4. Run clean-Mac install and permission test.
5. Publish the GitHub source repo.
6. Build Developer ID signed release artifacts.
7. Publish `updates/stable.json` only after the final updater ZIP exists.
8. Add search/tag polish to History.
9. Add user dictionary and correction-learning controls.
10. Evaluate true streaming/EOU after FluidAudio API and benchmark review.

## Non-Goals For First Public Source Release

- Cloud account system.
- Payment system.
- Hosted transcript storage.
- Public model hosting.
- App Store release.
- Bundled model weights.

## Useful Checks

```bash
swift test
swift build --product LocalVoiceFlowApp
LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp
Scripts/audit_sensitive_files.sh
Scripts/stage_site.sh
```
