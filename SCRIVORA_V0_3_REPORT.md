# Scrivora V0.3 Report

Date: 2026-06-12

## What We Had Before V0.3

Working:

- Local dictation loop with Hold Control.
- Microphone capture.
- FluidAudio Parakeet V2/V3 ASR.
- whisper.cpp CLI fallback.
- whisper-server fallback.
- VAD and silence endpointing.
- Floating overlay.
- Paste/copy fallback behavior.
- Local settings/history/learning/log stores.
- Debug latency metrics.
- Stable installed path at `/Applications/Scrivora.app`.

Problems:

- Fresh installs still allowed local text history by default in older code.
- Privacy choice was not explicit on first launch.
- Export was not available from the UI.
- Debug/support export did not have a redaction contract.
- Dev signing material lived in normal app support.
- Offline Mode was a UI setting without a tested core policy.
- The audit script did not exist.

## What Changed In V0.3

Privacy:

- Added `PrivacyProfile`.
- Fresh default is Maximum Privacy.
- Added first-run privacy choice.
- Added Privacy tab controls for history, learning memory, performance logs, target app metadata, raw audio, and Offline Mode.
- Added redacted debug export and full local export.
- Added tests for profiles, migration, Offline Mode, individual exports, redacted export, full export, and partial latency metrics.

Offline mode:

- In-app model downloads are blocked while Offline Mode is on.
- Local model files and localhost services remain allowed.

Exports:

- Settings only.
- History only.
- Learning only.
- Performance logs only.
- Full local package.
- Redacted debug package.

Redacted debug export removes:

- Transcript text.
- Correction text.
- Learned phrase rules.
- Target app names.
- Target bundle identifiers.
- Local filesystem paths.

Signing:

- Local development signing moved to `.build/dev-signing`.
- Old signing folder moved out of `~/Library/Application Support/LocalVoiceFlow/Signing`.
- Added `.gitignore` protections for signing material.
- Package script now builds version `0.3.0`.

Scripts:

- Added `Scripts/clean_dev_signing_material.sh`.
- Added `Scripts/audit_sensitive_files.sh`.
- Added release distribution stubs for package, notarize, staple, and verify.

Latency:

- First Parakeet partial attempts now start after about 0.75 seconds of captured audio instead of waiting for at least 1.0 second.
- First partial rolling window was reduced from 6 seconds to 3 seconds for the first attempt and 5 seconds for follow-up attempts.
- Debug metrics now split first partial request latency and first partial ASR duration.

Docs:

- Updated README.
- Added privacy audit.
- Added security model.
- Added security audit.
- Added distribution notes.
- Added battery benchmark notes.
- Added open-source strategy.

## Verification

Commands run:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
Scripts/install_app_bundle.sh
Scripts/audit_sensitive_files.sh
codesign -dv --verbose=4 /Applications/Scrivora.app
plutil -p /Applications/Scrivora.app/Contents/Info.plist
```

Results:

- `swift test`: 53 tests passed.
- `swift build --product LocalVoiceFlowApp`: passed.
- `Scripts/package_app_bundle.sh`: passed.
- `Scripts/install_app_bundle.sh`: installed `/Applications/Scrivora.app`.
- Bundle version: `0.3.0`.
- Bundle ID: `app.localvoiceflow.mvp`.
- Executable: `/Applications/Scrivora.app/Contents/MacOS/LocalVoiceFlowApp`.
- Signing authority: `LocalVoiceFlow Development`.
- Old app support signing folder: removed.
- Scrivora temp audio leftovers: none found.

Build warning still present:

- `NSRunningApplication.activate(options: [.activateIgnoringOtherApps])` is deprecated on macOS 14 and has no effect.

## Current Local State On This Mac

Installed app:

```text
/Applications/Scrivora.app
```

Local app data:

```text
~/Library/Application Support/LocalVoiceFlow
```

FluidAudio models:

```text
~/Library/Application Support/FluidAudio/Models
```

Development signing:

```text
/Users/rebel/Documents/wishperflow/.build/dev-signing
```

Local text stores currently exist on this Mac:

- Settings.
- Learning corrections.
- Performance logs.
- History.

These are local files from prior usage and can be cleared from Settings -> Privacy.

## What Is Still Not Production Ready

- Not Developer ID signed.
- Not notarized.
- No formal Instruments energy trace.
- Clipboard restoration is delay-based, not target-app acknowledged.
- Partial transcription is still pseudo-streaming over rolling chunks, not true token streaming.
- Partial latency should improve from the shorter first partial window, but a fresh live dictation measurement is still needed.
- whisper.cpp CLI still needs temporary WAV files.
- No encrypted export.
- No automatic purge for all third-party model caches.
- No clean-Mac install test.

## Next Steps

Priority 1:

- Replace deprecated target activation path with a macOS 14-safe paste focus strategy.
- Add paste substep metrics: clipboard snapshot, clipboard set, target activation, Command-V post, restore.
- Add a paste QA matrix for Notes, TextEdit, Chrome, Cursor, Codex, and Mail.

Priority 2:

- Formal resource benchmark:
  - Idle 30 minutes.
  - 100 short dictations.
  - 10 long dictations.
  - Parakeet V2 vs V3 vs whisper-server.

Priority 3:

- Make partial transcription feel closer to real streaming:
  - Measure chunk cadence.
  - Suppress unstable text.
  - Deduplicate partial-to-final more aggressively.
  - Keep final paste authoritative.

Priority 4:

- Production distribution:
  - Developer ID signing.
  - Hardened runtime.
  - Notarization.
  - Clean Mac install.

Priority 5:

- Open source preparation:
  - License.
  - Third-party notices.
  - Model license summary.
  - Security policy.
  - Clean clone build test.
