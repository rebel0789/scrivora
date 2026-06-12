# Scrivora Security Model

Date: 2026-06-12

## Trust Boundary

Scrivora is a local-first macOS app. The intended boundary is one user account on one Mac.

Trusted local components:

- Scrivora app process.
- Local app support directory.
- Local FluidAudio model cache.
- Local whisper.cpp binaries configured by the user.
- Local `whisper-server` when bound to `127.0.0.1`.

Untrusted or sensitive inputs:

- Microphone audio.
- Transcribed text.
- Target app metadata.
- User-provided model paths and binary paths.
- Imported or downloaded model files.

## Permissions

Required:

- Microphone: record audio for local transcription.
- Accessibility: detect dictation trigger and paste final text into the focused app.

Not required:

- Login.
- Cloud API credentials.
- Subscription.
- Contacts, calendar, location, camera, screen recording, or full disk access.

## Data Flow

Core loop:

```text
global trigger -> microphone capture -> in-memory audio buffer -> local ASR -> cleanup -> clipboard/paste -> local latency log
```

Default data retention:

- Audio: not saved.
- Transcript history: not saved on fresh install.
- Learning memory: not saved on fresh install.
- Performance metrics: saved locally without target app metadata.

## Model Execution

Preferred backend:

- FluidAudio Parakeet V2/V3 in process.

Fallback backends:

- Local whisper-server on localhost.
- Local whisper.cpp CLI.

The command backend still writes a temporary WAV because whisper.cpp CLI requires a file input. The file is deleted with `defer` after transcription.

## Clipboard And Paste

Text insertion copies the final transcript to the pasteboard first. If Accessibility paste fails, the transcript remains available for manual paste.

Clipboard restoration is opt-in from settings and runs after a configurable delay. This is useful but not perfect: the app cannot know if the target app consumed the paste before the delay expires.

## Signing

Development signing:

- Identity name: `LocalVoiceFlow Development`.
- Storage: `.build/dev-signing`.
- Purpose: stable macOS privacy identity during local builds.

Production signing:

- Must use Apple Developer ID Application certificate.
- Must notarize and staple the app before external distribution.

## Main Risks

- User-selected local binaries could be malicious.
- Local transcript history and correction memory contain user text when enabled.
- Debug Mode can log target app metadata.
- Command-line whisper fallback depends on temporary WAV cleanup.
- Non-notarized local builds are not production distribution artifacts.

## Mitigations Implemented

- Maximum Privacy default.
- First-run privacy profile choice.
- Local-only ASR path.
- Offline Mode blocks remote model downloads.
- Redacted debug export.
- Sensitive-file audit script.
- Dev signing material moved out of normal app support.
- `.gitignore` blocks common signing secrets and keychains.

## Next Security Work

- Add a production entitlement review before Developer ID signing.
- Add notarization script and release checklist.
- Add paste-step telemetry without recording text.
- Add explicit local binary trust UI for whisper paths.
- Add encrypted export option.
