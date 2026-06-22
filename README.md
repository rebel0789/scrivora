# Scrivora

Scrivora is a local-first dictation app for macOS. Speak, and your Mac writes.

The app records microphone audio, transcribes it locally, cleans the text, and
pastes the result into the focused app. Core dictation is designed to work
without a cloud speech API.

Scrivora is open-source software. You can inspect it, edit it, and build it
yourself. Normal users do not need Xcode or Swift: download the DMG, open it,
and drag Scrivora into Applications.

Source lives at `https://github.com/rebel0789/scrivora`.
The website is live at `https://scrivora.me`.

## Installation Guide

### Option A: Manual Download

Download the macOS DMG from the GitHub release:

```text
https://github.com/rebel0789/scrivora/releases/tag/v0.4.1
```

Then:

1. Open the DMG.
2. Drag `Scrivora.app` into `Applications`.
3. Open Scrivora from the menu bar and grant Microphone and Accessibility when
   macOS asks.

This is the visual drag-and-drop install path. It is the right path to use when
you want to inspect the DMG window and onboarding flow.

Optional checksum check:

```bash
shasum -a 256 ~/Downloads/Scrivora-0.4.1-preview-unnotarized.dmg
```

Compare the result with `SHA256SUMS.txt` on the GitHub release.

### Option B: Homebrew

Homebrew is optional. It is the cleanest free install path when macOS is strict
about unnotarized apps. Homebrew requires explicit trust for third-party casks.

```bash
brew tap rebel0789/scrivora https://github.com/rebel0789/scrivora
brew trust rebel0789/scrivora
brew install --cask scrivora
```

If Homebrew says the app already exists:

```bash
rm -rf "/Applications/Scrivora.app"
brew install --cask scrivora
```

The cask tries to remove quarantine from `Scrivora.app` only. It does not
disable Gatekeeper globally.

### macOS Says "App Is Damaged"

The free DMG is not Apple notarized yet. Some macOS versions show a warning such
as "Apple could not verify Scrivora is free of malware" or "Scrivora is damaged."
If that happens, remove quarantine from the downloaded DMG before opening it,
then drag Scrivora into Applications again:

```bash
xattr -d com.apple.quarantine ~/Downloads/Scrivora-0.4.1-preview-unnotarized.dmg
open ~/Downloads/Scrivora-0.4.1-preview-unnotarized.dmg
```

Then replace `Scrivora.app` in Applications from the DMG window and open it.

If you already copied the app and Terminal says `Operation not permitted` while
removing quarantine from `/Applications/Scrivora.app`, delete the copied app and
copy it again from the cleaned DMG. Do not disable Gatekeeper globally and do
not run broad quarantine commands over your whole Applications folder.

## What It Does

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

## Requirements For Users

- macOS 14 or newer.
- A downloaded preview DMG, or a Developer ID signed and notarized DMG when the
  paid signing path is available.

No account. No card. No cloud speech API for core dictation.

## Build From Source

Only developers need this path.

Requirements:

- Swift 6.1 or newer.
- Xcode 16 or newer if you want to package or sign a local app bundle.

Build and test:

```bash
swift test
swift build --product LocalVoiceFlowApp
```

Run with mock ASR when you want to test the UI without a large local model:

```bash
LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp
```

Install a local development app bundle:

```bash
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
```

## Local Models

Scrivora does not commit speech model weights to this repo.

Model downloads happen once, then Scrivora uses the local files. First-download
speed depends on the upstream model host and the user's network. The app shows
download progress, transfer speed, and time remaining so a slow CDN fetch does
not look frozen.

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

Before bundling or mirroring models, verify the upstream license and
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

Developer checks:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/audit_sensitive_files.sh
Scripts/stage_site.sh
```

Before attaching a public DMG, also run the clean-Mac install test, verify
Microphone and Accessibility permissions from a fresh user profile, and confirm
Gatekeeper accepts the signed artifact.

To check the DMG install view locally, mount the release artifact and inspect the
Finder window:

```bash
open .build/release-artifacts/Scrivora-0.4.1-preview-unnotarized.dmg
open /Volumes/Scrivora
```

Drag `Scrivora.app` into Applications, then verify the copied app:

```bash
xattr -l /Applications/Scrivora.app
codesign --verify --deep --strict --verbose=2 /Applications/Scrivora.app
open /Applications/Scrivora.app
```

For the lowest-friction free install route on strict macOS systems, use the
Homebrew cask path above. A warning-free DMG for everyone requires Developer ID
signing and Apple notarization.

## Website And Updates

The static website is prepared for:

```text
https://scrivora.me
```

Source repository:

```text
https://github.com/rebel0789/scrivora
```

GitHub Pages inputs live at the repo root and under `releases/` and `updates/`.
The production update endpoint is intended to be:

```text
https://scrivora.me/updates/stable.json
```

Publish `updates/stable.json` with the GitHub Release assets. Free builds use
that feed for release metadata and send users to the DMG release page. A
Developer ID build can use the same feed for in-app replacement updates after
the ZIP is signed, notarized, and generated from the exact uploaded app.

## Release Status

Use `RELEASE_STATUS.md` as the current release source of truth.

Current release tracks:

- Source repo: public on GitHub under the MIT license.
- Website: live at `https://scrivora.me`.
- Mac app binary: free preview DMG now; notarized Developer ID build later.
- Update feed: `https://scrivora.me/updates/stable.json` serves release
  metadata. Free builds open the release page for download.

See:

- `RELEASE_STATUS.md`
- `RELEASE_CHECKLIST.md`
- `OPEN_SOURCE_STRATEGY.md`
- `LICENSE`
- `LICENSE_PLAN.md`
- `MODEL_LICENSES.md`
- `THIRD_PARTY_NOTICES.md`
- `SECURITY.md`
- `CONTRIBUTING.md`
