# Scrivora

Scrivora is a local-first dictation app for macOS. Speak, and your Mac writes.

The app records microphone audio, transcribes it locally, cleans the text, and
pastes the result into the focused app. Core dictation is designed to work
without a cloud speech API.

> Status: private GitHub release staging is active at
> `https://github.com/rebel0789/scrivora`. The source tree is prepared for
> review; the public license decision, clean-clone check, and Developer ID
> signing/notarization remain release gates for a public Mac download. See
> `RELEASE_STATUS.md`.

## What Works

- macOS menu bar app.
- Hold Control, double-tap Control, and configurable global shortcut triggers.
- AVAudioEngine capture with 16 kHz mono audio processing.
- Local FluidAudio Parakeet V2/V3 transcription.
- Local whisper.cpp fallback for CLI or server-based transcription.
- App-aware text cleanup profiles.
- Clipboard paste into the focused app, with fallback behavior.
- Privacy controls for transcript storage and redacted export.
- Models screen with Parakeet V3 as the default local path and supported
  whisper.cpp downloads.
- Menu bar quick actions for dictation, model switching, latest transcript copy,
  History, updates, privacy mode, and data-folder access.
- Static website and update metadata templates for `https://scrivora.me`.
- Unit coverage for core settings, storage, model selection, cleanup, export,
  and trigger behavior.

Some internal Swift target names and migration paths still use the earlier
project name for compatibility. The public app name, bundle ID, website, and
release docs use Scrivora.

## Requirements

- macOS 14 or newer.
- Swift 6.1 or newer.
- Xcode 16 or newer for app bundle signing and local install flows.

## Build

```bash
swift test
swift build --product LocalVoiceFlowApp
```

Run the app with mock ASR when you want to test the UI and permissions without a
large local model:

```bash
LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp
```

Build and install a local app bundle:

```bash
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
```

## Local Models

Scrivora does not commit speech model weights to this repo.

FluidAudio Parakeet is the main local speech model path:

```bash
Scripts/download_fluidaudio_model.sh v3
Scripts/download_fluidaudio_model.sh v2
```

whisper.cpp is available as a local fallback:

```bash
Scripts/bootstrap_whisper_cpp.sh base.en-q5_1
Scripts/download_whisper_model.sh small.en-q5_1
```

Before publishing a public release, verify the upstream license and
redistribution terms for every model, binary, and generated artifact. See
`MODEL_LICENSES.md` and `THIRD_PARTY_NOTICES.md`.

## Privacy Model

Scrivora is designed around local processing.

- Audio capture stays on the Mac for local speech transcription.
- Transcript history is disabled on a fresh install unless the user enables it.
- Stored transcripts can be exported with redaction.
- Offline Mode is available for model-backed transcription that is already
  present on the machine.
- User data is stored under `~/Library/Application Support/LocalVoiceFlow/`.

Do not commit local model caches, transcripts, logs, recordings, app support
data, signing material, keychains, or generated release artifacts.

## Verification

Use the narrow checks first:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/audit_sensitive_files.sh
Scripts/stage_site.sh
```

Before a public Mac download, also run the clean-Mac install test, verify
Microphone and Accessibility permissions from a fresh user profile, and confirm
Gatekeeper accepts the signed artifact.

## Website And Updates

The static website is prepared for:

```text
https://scrivora.me
```

Repository staging:

```text
https://github.com/rebel0789/scrivora
```

GitHub Pages inputs live at the repo root and under `releases/` and `updates/`.
The production update endpoint is intended to be:

```text
https://scrivora.me/updates/stable.json
```

Only publish `updates/stable.json` after the updater ZIP has been built from a
Developer ID signed, notarized, and stapled app. Until then, use
`updates/stable.example.json` and `UPDATE_MANIFEST.example.json` as templates.

## Release Status

Use `RELEASE_STATUS.md` as the current release source of truth.

Current release tracks:

- Source repo: staged privately on GitHub for review.
- Website: staged locally for `https://scrivora.me` and ready to connect to the
  GitHub release path.
- Mac app binary: gated by Developer ID signing and notarization.
- In-app updates: manifest template only until the signed updater ZIP exists.

See:

- `RELEASE_STATUS.md`
- `RELEASE_CHECKLIST.md`
- `OPEN_SOURCE_STRATEGY.md`
- `LICENSE_PLAN.md`
- `MODEL_LICENSES.md`
- `THIRD_PARTY_NOTICES.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
