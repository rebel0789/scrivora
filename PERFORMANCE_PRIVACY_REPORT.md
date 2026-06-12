# Scrivora Status, Performance, and Privacy Report

Date: 2026-06-12 18:55 IST
Repo: `/Users/rebel/Documents/wishperflow`
Installed app tested: `/Applications/Scrivora.app`
Executable: `/Applications/Scrivora.app/Contents/MacOS/LocalVoiceFlowApp`

## V0.3 Privacy And Security Update

Implemented after the previous performance pass:

- Fresh installs now default to Maximum Privacy.
- First-run privacy choice asks the user before enabling transcript history or learning memory.
- Privacy screen exposes separate controls for transcript history, learning memory, performance logs, target app logging, target bundle logging, audio saving, and Offline Mode.
- Structured privacy export is implemented.
- Redacted debug export excludes transcript text, correction text, target app names, target bundle identifiers, local paths, audio, model files, and signing material.
- Offline Mode blocks remote model downloads from the app UI.
- Development signing material was moved out of normal app support and into `.build/dev-signing`.
- Sensitive-file audit and cleanup scripts were added.
- `swift test` now passes with 49 tests.

Not completed in V0.3:

- true FluidAudio streaming/EOU
- stop-to-insert metric sub-breakdown
- automated paste QA across every target app
- production Developer ID signing and notarization

## Summary

Scrivora is now a working local dictation MVP. The core loop is usable:

1. User triggers dictation with Control or the toolbar button.
2. App records microphone audio locally.
3. Local ASR transcribes with FluidAudio Parakeet. The current installed setting on this Mac is Parakeet V3; the fresh-install code default is Parakeet V2.
4. Cleanup/profile logic formats the transcript.
5. Text is copied to clipboard and pasted into the focused app when Accessibility permission allows it.
6. Latency metrics are written locally and displayed in the Debug screen.

The main issue found during this audit was idle CPU waste from the floating overlay. The overlay used a continuous SwiftUI animation timeline even when the app was idle. That has been fixed in `Sources/LocalVoiceFlowApp/Views.swift`: idle and reduced-motion states now render a static Canvas; only recording and processing animate.

Follow-up implemented after the first report:

- Privacy Mode now redacts target app name and target bundle identifier from new performance log entries.
- Privacy screen now shows tracked local storage sizes.
- Privacy screen now has controls to clear transcript history, learning memory, performance logs, or all local text/debug data together.
- Performance log storage now has a tested clear path.

V0.3 privacy hardening added after this report:

- Fresh installs now default to Maximum Privacy: no transcript history, no learning memory, no target app metadata, no audio saving.
- First-run privacy profile choice is implemented.
- Settings -> Privacy can export settings/history/learning/log packages.
- Redacted debug export removes transcript text, correction text, target app metadata, bundle identifiers, learned phrase entries, and local paths.
- Offline Mode blocks in-app remote model downloads while keeping local models and localhost helpers usable.
- Dev signing material moved to ignored `.build/dev-signing`.
- Latest `swift test`: 49 tests passed.
- Latest package/install verification: `/Applications/Scrivora.app`, version `0.3.0`, signed with `LocalVoiceFlow Development`.

## What We Built So Far

### Core Dictation Loop

- Global trigger support:
  - Hold Control.
  - Double-tap/toggle architecture still exists.
  - Toolbar Dictate button can start and stop recording.
- Microphone recording pipeline:
  - Captures local mic audio.
  - Updates a voice-level/spectrum signal for the floating overlay.
  - Runs silence detection and VAD-driven state updates.
- Local transcription:
  - FluidAudio Parakeet is the current practical path. V3 is selected on this Mac; V2 is the fresh-install default.
  - whisper.cpp CLI and whisper-server backends remain as fallbacks.
  - WhisperKit is present in the model catalog directionally, but it is not the proven production path yet.
- Cleanup and output profiles:
  - General, coding/pragmatic, agent, and email style profiles.
  - Filler cleanup for small "uh/ah" style words.
  - Silence artifact removal.
  - Command cleanup for punctuation and formatting.
  - Personal correction learning stored locally.
- Text insertion:
  - Copies transcript to clipboard first.
  - Sends Command-V through Accessibility when auto-paste is enabled and trusted.
  - Restores the previous clipboard after a configurable delay.
  - Falls back to copied text if auto-paste is disabled or insertion fails.
- Local metrics:
  - Hotkey-to-recording latency.
  - Speech detection latency.
  - First partial latency.
  - Speech-end-to-final-ASR latency.
  - Cleanup-to-paste latency.
  - Model load and warmup time where available.

### UX and Settings

- App is branded as Scrivora.
- Sidebar screens exist for Dashboard, Dictation, AI Models, Cleanup, History, Privacy, Debug, and About.
- Permissions UI shows Microphone and Accessibility state.
- Floating overlay now has:
  - Three animation styles: Liquid Flow, Spectrum Bloom, Minimal Signal.
  - Four palettes: Aurora, Graphite, Ink, Silver.
  - Fixed low-power idle behavior.

## Current Resource Measurements

Measurements were taken against `/Applications/Scrivora.app` on 2026-06-12.

### Before The Idle Animation Fix

Command:

```bash
ps -p "$PID" -o rss=,vsz=,pcpu=,pmem=,time=
```

Hidden idle sample before the fix:

- RSS: about 142 MB.
- Physical footprint: about 71 MB.
- CPU: steady about 9-14% while idle.
- Top POWER column: 0-8.7 depending on sample.

Cause:

- `VoiceFlowSymbol` used `TimelineView(.animation)` unconditionally, so SwiftUI redrew the overlay even when runtime state was Idle.

### After The Idle Animation Fix

Hidden idle sample after reinstalling the fixed build:

```text
18:50:16 130240   0.0  0.4   0:00.55
18:50:17 130240   0.0  0.4   0:00.55
18:50:18 130240   0.0  0.4   0:00.55
18:50:19 130240   0.0  0.4   0:00.55
```

Visible dashboard idle after settling:

```text
18:54:20 150608   0.0  0.4   0:18.86
18:54:21 110224   0.0  0.3   0:18.86
18:54:22 106128   0.0  0.3   0:18.87
18:54:23 106672   0.0  0.3   0:18.87
```

Footprint after fixed idle launch:

```text
Footprint: 32 MB
Physical footprint peak: 44 MB
```

Steady idle result:

- CPU: 0.0% after the overlay fix.
- RSS: about 106-130 MB depending on window state.
- Physical footprint: 32 MB fresh idle, 55-59 MB after a dictation pass.
- Peak physical footprint observed: 84 MB after active dictation.

### Local Competitor Idle Snapshot

Measured on the same Mac on 2026-06-12 after launching each app and sampling the full process tree where applicable:

```text
Scrivora   130 MB   0.0% CPU
VoiceInk   108 MB   0.0% CPU
Vowen      659 MB   1.5% CPU
Wispr Flow  58 MB   113-122% CPU in this sample
```

Notes:

- Scrivora and VoiceInk were similar at idle.
- Vowen is much heavier at idle because it launches multiple Electron/helper processes, including GPU, renderer, audio, network, audio-recorder, and MacKeyServer helpers.
- Wispr Flow was already running and showed high CPU during this sample. That may indicate active/stuck background work on this machine, so treat it as a local observation rather than a universal benchmark.
- Active competitor dictation was not measured because it requires starting each app's recording path manually and consistently. Scrivora active dictation was measured directly through its toolbar dictation path.

### Active Dictation Sample

The toolbar Dictate button was used for a short real recording pass. It picked up ambient speech and produced one new local transcript.

Active recording sample:

```text
18:52:24 115744  26.3  0.3   0:01.20
18:52:25 116000  26.0  0.3   0:01.46
18:52:27 116432  25.4  0.3   0:01.71
18:52:28 116848  26.1  0.3   0:01.98
18:52:29 116864  23.7  0.3   0:02.23
18:52:30 128672  31.5  0.4   0:02.51
18:52:31 156400  31.1  0.5   0:02.92
18:52:32 156592  24.6  0.5   0:03.16
```

Active result:

- CPU: about 24-31% during recording/transcription.
- RSS: about 115-156 MB during the active pass.
- Physical footprint after active use: 59 MB.
- Neural/ANE mapped memory observed by `footprint`: 468 MB nofootprint. This is expected for the Parakeet/FluidAudio path and is not counted in the process physical footprint, but it is real accelerator memory pressure.

On this Mac, `%CPU` is reported relative to one logical CPU core. The machine has 12 logical cores, so 24-31% active dictation is roughly a quarter to a third of one core, not 24-31% of the whole machine. That is acceptable for a short local inference burst, but it would be unacceptable if it happened continuously while idle.

After hiding the app and waiting about 20 seconds:

```text
18:53:45 191216   0.0  0.6   0:18.81
18:53:46 191216   0.0  0.6   0:18.81
18:53:47 191216   0.0  0.6   0:18.81
```

Conclusion:

- Idle waste is fixed.
- Active CPU is acceptable for local ASR but should be benchmarked on longer samples and battery laptops.
- The app settles back to idle cleanly after active work.

### Energy

Available non-root evidence:

- `top -stats power` showed 0.0 POWER in fixed idle.
- Active CPU during dictation was about 24-31%, which is the current best non-root proxy for energy use.
- `powermetrics --samplers tasks` requires root and was not run with elevated privileges.

Recommended next measurement:

```bash
sudo powermetrics --samplers tasks -n 10 -i 1000
```

Run that once while idle and once while recording a 30-second dictation. Do not run it as part of normal app behavior.

## Latency Evidence

Recent local performance log example:

```json
{
  "asrBackend": "fluidAudio",
  "durationRecorded": 2.4,
  "metrics": {
    "cleanupToPaste": 0.830820292,
    "finalASRToCleanup": 0.000539667,
    "firstPartialLatency": 1.4137920141220093,
    "hotkeyToRecordingStart": 0.0007050037384033203,
    "modelLoadTime": 0.186056667,
    "modelWarmupTime": 0.000060959,
    "pasteMethod": "clipboardPaste",
    "recordingStartToSpeechDetected": 0.07555902004241943,
    "speechEndToFinalASR": 0.111643375,
    "stopSpeakingToInsertedText": 1.1082819700241089
  },
  "modelID": "fluidaudio-parakeet-v3",
  "outputProfile": "agent",
  "pasteMethod": "clipboardPaste",
  "streamingMode": "pseudoStreaming",
  "targetAppName": "Codex",
  "targetBundleIdentifier": "com.openai.codex",
  "triggerMode": "holdControl"
}
```

Important interpretation:

- Parakeet V3 is fast enough for the MVP.
- The largest measured user-visible cost is still cleanup-to-paste plus end-to-insert, not final ASR.
- First partial latency around 1.4-2.1 seconds is usable but not yet Wispr-level streaming UX.

## Permissions Audit

### Info.plist

Current Info.plist has only:

- `NSMicrophoneUsageDescription`

No camera, location, contacts, calendar, photos, Bluetooth, or Apple Events usage descriptions are present.

### Accessibility

Accessibility is required for two product behaviors:

- Listen-only Control event tap for global trigger.
- Posting Command-V into the focused app.

Relevant code:

- `PermissionsManager` uses `AVCaptureDevice.authorizationStatus(for: .audio)` and `AXIsProcessTrustedWithOptions`.
- `HotkeyManager` creates a `cgSessionEventTap` with `.listenOnly`.
- `TextInsertionService` posts Command-V using `CGEvent`.

Current installed state from app UI:

- Microphone: Granted.
- Accessibility: Granted.

### Signing And Gatekeeper

Current build:

- Signed with local development identity: `LocalVoiceFlow Development`.
- TeamIdentifier: not set.
- `spctl -a -vv /Applications/Scrivora.app`: rejected.

This is expected for a local development build. For real distribution, the app needs a Developer ID signature and notarization.

### Entitlements

`codesign --entitlements :- /Applications/Scrivora.app` did not print an entitlement plist.

Meaning:

- The app is currently unsandboxed.
- There are no explicit sandbox, camera, iCloud, Apple Events, or network entitlements.
- Because it is unsandboxed, macOS does not use entitlements to restrict filesystem/network access. This is normal for many direct-distributed Mac utilities, but it should be a deliberate production decision.

## Local Data And Logging Audit

### App Support Directory

Current app support root:

```text
/Users/rebel/Library/Application Support/LocalVoiceFlow
```

Current size:

```text
238M
```

Current files:

```text
History/history.json                         37K
Learning/corrections.json                    1.1K
Logs/dictation-performance.jsonl             31K
Models/ggml-base.en-q5_1.bin                 57M
Models/ggml-small.en-q5_1.bin                181M
Settings/settings.json                       2.0K
Signing/*                                    local development signing material
```

FluidAudio model cache:

```text
/Users/rebel/Library/Application Support/FluidAudio
904M
```

Counts during this audit:

- History records: 56.
- Learned correction records: 2.
- Performance log lines: 350.

### What Is Stored

Stored locally:

- Settings.
- Transcript history, if enabled.
- Learned correction pairs.
- Performance metrics.
- Local Whisper model files.
- FluidAudio model cache.

Not stored by default:

- Raw audio.
- Cloud analytics.
- Remote transcription payloads.

### Privacy Settings

Current settings:

```json
{
  "analyticsEnabled": false,
  "offlineMode": false,
  "privacyMode": false,
  "saveAudio": false,
  "saveTranscriptHistory": true
}
```

Interpretation:

- Audio saving is off.
- Transcript history is on, so dictated text is stored locally in `History/history.json`.
- Privacy Mode disables history writes when enabled.
- Analytics are off.

### Performance Logs

Performance logs do not contain transcript text or audio.

They do contain:

- Timestamp.
- Trigger mode.
- ASR backend and model id.
- Output profile.
- Target app name.
- Target bundle identifier.
- Recording duration.
- Latency metrics.
- Paste method.
- Error string if any.

This is acceptable for local debugging, but for a privacy-first product it should be user-clear because target app names can still reveal behavior.

Current mitigation:

- When Privacy Mode is enabled, new performance log entries keep timing/model/paste metrics but redact target app name and target bundle identifier.

### History And Learning

`History/history.json` stores full final transcripts while transcript history is enabled.

`Learning/corrections.json` stores:

- Original transcript.
- Corrected transcript.
- Learned replacement entries.
- Target app metadata if available.

This is local-only, but it is personal text data. Production UX should make this visible and easy to clear.

### Audio Files

No leftover temp WAV files were found in `/tmp` or `$TMPDIR`.

whisper.cpp fallback behavior:

- Writes a temporary WAV to the system temp directory.
- Deletes it with `defer`.

FluidAudio/Parakeet path:

- Uses in-memory audio buffers for the app path.
- Does not persist raw audio by default.

## Network Audit

The app/repo contains network access for:

- Model downloads from Hugging Face.
- Cloning/building FluidAudio or whisper.cpp in setup scripts.
- whisper-server local HTTP calls to `http://host:port/inference`.

No cloud ASR API path was found in the real app flow.

Production recommendation:

- Keep model download UI explicit.
- Make Offline Mode block remote model download attempts.
- Keep localhost whisper-server clearly separated from internet requests in UI/copy.

## Security And Privacy Issues To Fix Before Shipping

1. Local signing material is in app support.
   - The current `Signing/` directory includes a development private key, p12, keychain db, and password file under `~/Library/Application Support/LocalVoiceFlow`.
   - This is acceptable only as a local dev bootstrap.
   - Move build signing material to a dev-only build cache or macOS Keychain-only flow before production.

2. Transcript history is enabled by default in current user settings.
   - It is local, but it still stores dictated text.
   - For a privacy-first product, first-run onboarding should ask whether to keep history.

3. Performance logs include target app name and bundle id.
   - Useful for debugging and per-app profiles.
   - Still metadata.
   - Add a setting to disable target-app metadata in performance logs or auto-redact it in Privacy Mode.

4. The app is unsandboxed.
   - This may be necessary for global hotkeys and paste automation in a direct-distributed utility.
   - The production decision should be documented.
   - If staying unsandboxed, keep the code path narrow and transparent.

5. Gatekeeper rejects the local build.
   - Needs Developer ID signing and notarization for real distribution.

## Performance Issues To Watch

1. Active ASR CPU is non-trivial.
   - 24-31% CPU observed during short active dictation.
   - Acceptable for a desktop local ASR MVP, but must be measured on MacBook battery.

2. ANE/neural mapped memory is large.
   - `footprint` observed 468 MB neural nofootprint after Parakeet use.
   - This is probably model/runtime accelerator memory.
   - It did not show as process physical footprint, but it can matter under memory pressure.

3. First partial latency is still not ideal.
   - Current pseudo-streaming partials are around 1.4-2.1 seconds in recent logs.
   - For Wispr-like feel, this needs true incremental streaming or a lower-latency partial path.

4. clipboardRestoreDelay is a UX/performance tradeoff.
   - Current setting is 600 ms.
   - This protects the previous clipboard but contributes to stop-to-insert latency.

## Verification Run

Commands run:

```bash
swift build --product LocalVoiceFlowApp
swift test
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
ps -p "$PID" -o rss=,pcpu=,pmem=,time=
top -l 3 -pid "$PID" -stats pid,command,cpu,mem,power,time
footprint -p "$PID" -summary
vmmap -summary "$PID"
codesign -dvvv --entitlements :- /Applications/Scrivora.app
spctl -a -vv /Applications/Scrivora.app
log show --last 10m --predicate 'process == "LocalVoiceFlowApp"' --style compact
```

Results:

- `swift build --product LocalVoiceFlowApp`: passed.
- `swift test`: 44 tests passed.
- Installed app: `/Applications/Scrivora.app`.
- Microphone permission: granted.
- Accessibility permission: granted.
- Local performance logs: written.
- No unified-log app output observed in the 10-minute process query.
- No temp WAV leftovers found.

## Next Steps

Highest-priority next work:

1. Add a Privacy export screen:
   - The clear controls and exact storage sizes are now implemented.
   - Export still needs structured JSON export for history, learning, and settings.

2. Add an explicit first-run privacy choice:
   - Keep transcript history.
   - Keep only metrics.
   - Privacy Mode.

3. Move signing material out of app support:
   - Dev-only cache or Keychain-only.
   - Never sync/store signing passwords beside app data.

4. Add an in-app resource/debug panel:
   - Current process RSS/footprint if available.
   - Last 10 dictation latency averages.
   - Model disk usage.
   - History/log/learning file sizes.

5. Improve partial transcription:
   - Move from pseudo-streaming to true partial ASR if FluidAudio supports it.
   - Keep unstable partial text out of paste.
   - Continue deduplication in final transcript builder.

6. Production distribution:
   - Developer ID signing.
   - Notarization.
   - Document why Accessibility is needed.
   - Document unsandboxed decision if retained.
