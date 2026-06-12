# Scrivora Project Status And Roadmap

Date: 2026-06-12
Repo: `/Users/rebel/Documents/wishperflow`
Installed app: `/Applications/Scrivora.app`
Bundle ID: `app.localvoiceflow.mvp`
Executable target: `LocalVoiceFlowApp`
Core module: `LocalVoiceFlowCore`

This is the single handoff document for what has been done, what is working, what is still weak, and what we should do next. More detailed supporting docs live in:

- `AUDIT.md`
- `CONTEXT_TREE.md`
- `BENCHMARKS_LOCAL.md`
- `ACCURACY_TEST.md`
- `PASTE_QA.md`
- `PERFORMANCE_PRIVACY_REPORT.md`
- `TECHNICAL_DESIGN.md`
- `README.md`

## 1. Product Goal

Scrivora is a local-first macOS dictation app.

The core product loop is:

```text
global trigger
-> record microphone
-> transcribe locally
-> cleanup text locally
-> paste into the focused app
-> leave clipboard fallback if paste fails
-> log local latency metrics
```

Hard constraints:

- No cloud transcription.
- No login.
- No subscription.
- No audio saved by default.
- No mock ASR in the real app path.
- No fake success states.
- Keep the UI responsive.
- Do not block the main thread.

The product should feel close to Wispr Flow in daily use, but remain local-first and transparent about permissions, models, and stored data.

## 2. Current Machine State

Current installed settings on this Mac:

```text
Selected model: FluidAudio Parakeet V3
Selected ASR mode: Balanced
Trigger: Hold Control
Overlay style: Spectrum Bloom
Overlay palette: Graphite
Auto-paste: on
Copy to clipboard: on
Clipboard restore: on, 600 ms
Privacy Mode: off
Save audio: off
Save transcript history: on
Analytics: off
```

Important default distinction:

- Code default for a fresh install is `fluidaudio-parakeet-v2`.
- The current installed user setting on this Mac is `fluidaudio-parakeet-v3`.

Current local storage snapshot:

```text
LocalVoiceFlow app data: 238 MB
FluidAudio model cache: 904 MB
Saved history records: 56
Correction records: 2
Performance log lines: 350
```

Current installed app idle sample:

```text
RSS: about 134 MB
CPU: 0.0%
```

## 3. What We Built

### 3.1 App Foundation

Built a SwiftPM macOS app with:

- `LocalVoiceFlowCore` for model contracts, settings, stores, audio primitives, text cleanup, and metrics.
- `LocalVoiceFlowApp` for SwiftUI/AppKit UI, hotkeys, audio capture, ASR engine construction, permissions, paste, and overlay.
- Menu bar app shell.
- Main settings/dashboard window.
- App packaging scripts.
- Install script for `/Applications/Scrivora.app`.
- Local development signing flow.

The public product name is now Scrivora. Internal Swift target names still use `LocalVoiceFlow*` to avoid a risky rename while the MVP is moving quickly.

### 3.2 Packaging And Installation

Implemented and verified:

- `Scripts/package_app_bundle.sh`
- `Scripts/install_app_bundle.sh`
- `.build/Scrivora.app`
- `/Applications/Scrivora.app`
- `NSMicrophoneUsageDescription` in Info.plist
- Stable bundle ID `app.localvoiceflow.mvp`
- Local development code signing with `LocalVoiceFlow Development`

Known limitation:

- Gatekeeper rejects the app because it is locally signed, not Developer ID signed and notarized.

### 3.3 Permissions

Implemented:

- Microphone permission check through `AVCaptureDevice.authorizationStatus(for: .audio)`.
- Microphone permission request.
- Accessibility trust check through `AXIsProcessTrusted`.
- Accessibility prompt through `AXIsProcessTrustedWithOptions`.
- Open System Settings to Accessibility.
- Dashboard permission status for Microphone and Accessibility.

Current measured state:

```text
Microphone: Granted
Accessibility: Granted
```

Why Accessibility is needed:

- Global Control trigger uses a listen-only CGEvent tap.
- Auto-paste posts Command-V into the focused app.

No camera, location, contacts, calendar, photos, Bluetooth, or Apple Events usage strings are present.

### 3.4 Hotkey And Trigger

Implemented:

- Hold Control trigger.
- Double-tap Control trigger path.
- Original global shortcut path still exists.
- Control event tap listens without modifying input.
- Hotkey registration refreshes when settings change.
- Trigger latency is logged.

Current practical default:

```text
Hold Control
```

Why this matters:

- The earlier multi-key shortcut felt bad.
- A modifier-only Control trigger is closer to the market leader UX.
- The user tested this and confirmed dictation works.

### 3.5 Audio Capture

Implemented:

- `AVAudioEngine` microphone capture.
- Conversion to 16 kHz mono samples.
- In-memory audio ring buffer.
- No microphone audio saved by default.
- Voice level and spectrum calculation for the overlay.

Current limitation:

- No input-device picker polish yet.
- No advanced noise suppression.
- No neural VAD yet.

### 3.6 VAD And Endpointing

Implemented:

- Energy-based `VoiceActivityDetector`.
- `SilenceDetector`.
- Auto-stop on silence.
- Runtime states for idle, listening, speech detected, partial transcription, processing, finished, failed.
- Metrics for recording start to speech detected.

Current limitation:

- VAD is basic energy VAD.
- It can false-trigger or miss speech in noisy rooms.
- We should benchmark Silero/WebRTC/FluidAudio endpointing before shipping.

### 3.7 ASR Backends

Implemented backends:

- `WhisperCppCLIEngine`
- `WhisperCppServerEngine`
- `FluidAudioBatchASREngine`
- `MockASREngine` only for tests and explicit mock runs.

The real app path is no longer mock ASR.

whisper.cpp path:

- Uses Homebrew `whisper-cpp`.
- Supports `whisper-cli`.
- Supports persistent local `whisper-server`.
- Keeps whisper.cpp fallback available.
- CLI/server fallback writes a temp WAV and deletes it.

FluidAudio/Parakeet path:

- Adds FluidAudio as an app-target dependency.
- Keeps `ASREngine` in Core so Core stays independent.
- Loads Parakeet V2 and V3 from FluidAudio model cache.
- Transcribes in-memory app samples.
- Does not write app microphone audio to temp WAV in the app path.
- Keeps model loaded in-process across dictations.

Model catalog:

- `fluidaudio-parakeet-v2`
- `fluidaudio-parakeet-v3`
- whisper.cpp tiny/base/small quantized models
- placeholder/future WhisperKit lane

Current code default:

```text
Parakeet V2 English
```

Current user-selected model on this Mac:

```text
Parakeet V3
```

### 3.8 Model Setup

Implemented:

- `Scripts/download_whisper_model.sh`
- `Scripts/download_fluidaudio_model.sh`
- `Scripts/bootstrap_whisper_cpp.sh`
- app-side model catalog and download UI
- explicit whisper binary/model path settings
- persistent whisper-server preference
- recovery for interrupted Parakeet downloads
- stable ignored `Vendor/FluidAudio` mirror after `/tmp/FluidAudio` mirror brittleness

Verified:

- Homebrew `whisper-cpp` installed.
- whisper.cpp base model downloaded.
- Parakeet V2 cache repaired and verified.
- Parakeet V3 downloaded and verified.

### 3.9 Transcription Quality

Observed:

- whisper.cpp base/small was usable but weak for the user's accent/slang.
- Parakeet was much better on the user's voice.
- Parakeet V3 is currently selected on this Mac.
- Synthetic `say` samples are useful for smoke tests but not enough for production quality claims.

Implemented cleanup improvements:

- Remove non-speech artifacts like `[Silence]`.
- Drop silence-only transcripts.
- Remove small filler words.
- Reduce repeated words/fragments.
- Handle punctuation commands.
- Handle line/list commands.
- Apply deterministic replacements.
- Add app/profile-aware cleanup.
- Add user dictionary entries from corrections.

Current limitation:

- No model training.
- The improvement curve is local post-ASR adaptation, not ASR fine-tuning.

### 3.10 App-Specific Output Profiles

Implemented:

- `Automatic`
- `General`
- `Pragmatic`
- `Agent`
- `Email`
- `Raw`

Routing:

- Coding apps map toward Pragmatic.
- Agent apps map toward Agent.
- Email apps map toward Email.
- Notes/TextEdit/general apps map toward General.

Current limitation:

- Browser tab-specific detection is not implemented.
- App list coverage should be expanded by real user QA.

### 3.11 Paste And Clipboard

Implemented:

- Copy final transcript to clipboard first.
- Auto-paste through Command-V when Accessibility is trusted.
- Activate target app before paste when needed.
- Restore previous clipboard after a configurable delay.
- Keep copied transcript as fallback when paste fails.

Current default:

```text
autoPaste: true
copyToClipboard: true
restoreClipboardAfterPaste: true
restore delay: 600 ms
```

Current limitation:

- Paste matrix still needs systematic manual QA in Notes, TextEdit, Chrome, Cursor, VS Code, Terminal, Gmail, Slack, Notion, Google Docs, and other real targets.

### 3.12 Latency Metrics

Implemented:

- hotkey to recording start
- recording start to speech detected
- first partial latency
- speech end to final ASR
- final ASR to cleanup
- cleanup to paste
- stop speaking to inserted text
- model load time
- model warmup time
- paste method

Metrics are shown in Debug and stored locally in:

```text
~/Library/Application Support/LocalVoiceFlow/Logs/dictation-performance.jsonl
```

Current recent example:

```text
recordingStartToSpeechDetected: about 0.076 s
speechEndToFinalASR: about 0.112 s
firstPartialLatency: about 1.414 s
cleanupToPaste: about 0.831 s
stopSpeakingToInsertedText: about 1.108 s
```

Interpretation:

- Final ASR is fast enough with Parakeet.
- First partial is still too slow for best-in-market feel.
- Paste/clipboard restore contributes a lot to perceived latency.

### 3.13 Partial Transcription

Implemented:

- Rolling-window pseudo-streaming partials using Parakeet batch calls.
- Partial stabilizer to avoid pasting unstable partial text.
- First partial latency metric.
- Overlay can show partial/transcribing state.

Not implemented:

- True streaming ASR.
- FluidAudio EOU streaming integration.
- Embedded whisper.cpp streaming.
- WhisperKit streaming.

This is the next major technical UX gap.

### 3.14 History And Learning

Implemented:

- Local transcript history.
- Local correction records.
- Correction learning.
- User dictionary entries.
- Clear correction memory.
- History correction UI.

Privacy behavior:

- History is stored only if `saveTranscriptHistory` is true and Privacy Mode is off.
- Privacy Mode blocks new history writes.

Current local state:

```text
History records: 56
Correction records: 2
```

### 3.15 Privacy Controls

Implemented:

- Privacy Mode toggle.
- Save transcript history toggle.
- Save audio toggle, default off.
- Offline mode toggle.
- Open data folder.
- Local storage size breakdown in Privacy screen.
- Clear history.
- Clear learning memory.
- Clear performance logs.
- Clear history, learning, and logs together.
- Privacy Mode redacts target app name and bundle ID from new performance logs.

Stored locally:

- Settings.
- Transcript history, if enabled.
- Correction memory.
- Performance metrics.
- Local model files.

Not stored by default:

- Raw audio.
- Cloud analytics.
- Cloud ASR payloads.

Current risk:

- Transcript history is on in this user's current settings.
- Performance logs still store target app metadata when Privacy Mode is off.
- Local development signing material currently lives under app support and must move before production.

### 3.16 UI And Overlay

Implemented:

- Scrivora branding.
- Dashboard.
- Dictation settings.
- AI Models screen.
- Cleanup screen.
- History screen.
- Privacy screen.
- Debug screen.
- About screen.
- Floating overlay controller.
- Small bottom overlay.
- Three overlay animation styles:
  - Liquid Flow
  - Spectrum Bloom
  - Minimal Signal
- Four palettes:
  - Aurora
  - Graphite
  - Ink
  - Silver

Important performance fix:

- The overlay previously used `TimelineView(.animation)` even while idle.
- That caused about 9-14% idle CPU.
- It now renders static while idle or reduced motion is enabled.
- It only animates while recording or processing.

Current idle after fix:

```text
CPU: 0.0%
```

## 4. What We Verified

Commands verified during the build:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
```

Latest verification:

```text
swift test: 45 tests passed
swift build --product LocalVoiceFlowApp: passed
installed app: /Applications/Scrivora.app
idle CPU: 0.0%
```

ASR verification:

- Direct whisper.cpp CLI works.
- Swift whisper.cpp CLI integration test passes.
- Swift whisper.cpp server integration test passes.
- FluidAudio Parakeet V2 and V3 model paths are verified.
- Parakeet real app path is now the practical default direction.

User validation:

- User confirmed dictation is working.
- User confirmed voice recognition is now much better than the earlier whisper.cpp path.
- User tested Codex, Cursor, and Notes.
- User wants app-specific output behavior and better punctuation/filler cleanup.
- User wants better UI/overlay polish similar to Wispr Flow.

## 5. Resource And Competitor Comparison

Measured on this Mac after launching each app:

```text
Scrivora   about 130 MB   0.0% CPU
VoiceInk   about 108 MB   0.0% CPU
Vowen      about 659 MB   1.5% CPU
Wispr Flow about 58 MB    113-122% CPU in this local sample
```

Interpretation:

- Scrivora is now excellent at idle.
- VoiceInk is slightly lighter in idle RAM.
- Vowen is much heavier because it launches Electron/helper processes.
- Wispr Flow showed high CPU in this local sample, likely because it was doing or stuck in background work. Treat that as local observation, not a universal claim.

Active dictation:

```text
Scrivora active dictation CPU: about 24-31%
```

This is per logical core. On the M2 Max with 12 logical cores, that is about a quarter to a third of one core during active local inference. That is acceptable for short local dictation bursts. It would be unacceptable only if it happened while idle.

## 6. What Is Fully Working

- The app builds.
- The app installs.
- The app launches.
- Microphone permission path works.
- Accessibility permission path works.
- Hold Control dictation works.
- Local Parakeet transcription works.
- whisper.cpp fallback works.
- Audio is not saved by default.
- Text cleanup works for common artifacts, filler, commands, replacements, and profiles.
- Paste/copy path works in the main tested flow.
- Local history works.
- Local correction learning works.
- Latency logs work.
- Privacy Mode blocks new history writes and redacts target app metadata in new metrics.
- Idle CPU is fixed at 0%.

## 7. What Is Partially Working

- Partial transcription is pseudo-streaming, not true streaming.
- VAD is energy-based, not neural.
- App-specific output routing works by app/bundle, not browser tab/content.
- Clipboard restore works by delay, but needs more target-app QA.
- UI is usable but not yet product-grade enough for a daily paid app.
- Model setup is much better but still developer-ish in places.
- Performance screen shows latency, not full CPU/energy/memory live graphs.

## 8. What Is Mocked Or Test-Only

- `MockASREngine` exists for tests and explicit mock runs only.
- LLM cleanup is not implemented as a real backend.
- True streaming is not implemented.
- WhisperKit is not production integrated.
- Direct accessibility text insertion is not the primary delivery path.

## 9. What Is Still Not Production-Ready

### 9.1 Product Reliability

- Need a full paste QA matrix.
- Need a full real voice benchmark set.
- Need first-run setup that explains permissions and model downloads clearly.
- Need app restart/update permission stability checks.

### 9.2 ASR And Latency

- True streaming partials are missing.
- First partial latency is around 1.4-2.1 seconds in recent logs.
- VAD needs a stronger endpointing path.
- Need battery Mac energy tests.
- Need long dictation tests.

### 9.3 Privacy

- Need first-run choice for transcript history.
- Need export local data.
- Need better explanation of exactly what is stored.
- Need local signing secrets moved out of app support.

### 9.4 Packaging

- Need Developer ID signing.
- Need notarization.
- Need hardened runtime review.
- Need a clean release build path.

### 9.5 UX

- Overlay is better and low-power now, but animation still needs product polish.
- Main app UI is better than scaffold, but not yet best-in-market.
- Debug screen should include resource stats, not only latency.
- Model setup should feel like one guided checklist.

## 10. Next Steps

### Phase 1: Lock The Current MVP Baseline

Goal: make the current app reliable enough for daily internal use.

Tasks:

1. Run a target-app paste QA pass.
   - Notes
   - TextEdit
   - Chrome
   - Safari
   - Cursor
   - VS Code
   - Terminal
   - Gmail
   - Slack
   - Notion
   - Google Docs

2. Record results in `PASTE_QA.md`.

3. For each target app, capture:
   - pasted automatically or copied only
   - prior clipboard restored or not
   - recommended restore delay
   - profile selected
   - failure text if any

Acceptance:

```text
Notes, TextEdit, Chrome, Cursor, and Codex paste reliably.
If paste fails, the final transcript remains copied.
No fake success state.
```

### Phase 2: Real Voice Benchmark Set

Goal: stop guessing which ASR model is best.

Tasks:

1. Record 10-20 local voice samples.
2. Include accent/slang, short phrases, long sentences, noisy room, punctuation commands, and app-like prompts.
3. Benchmark:
   - Parakeet V2
   - Parakeet V3
   - whisper.cpp base/small fallback
4. Measure:
   - WER
   - CER
   - latency
   - confidence if available
   - punctuation quality
   - hallucinations
5. Update `BENCHMARKS_LOCAL.md`.

Acceptance:

```text
Default model choice is based on real user voice data.
We know when V2 beats V3 and when whisper fallback is useful.
```

### Phase 3: True Partial Transcription

Goal: make the overlay feel alive and fast, not delayed.

Tasks:

1. Investigate FluidAudio streaming or EOU APIs.
2. If FluidAudio streaming is practical, implement a streaming ASR engine.
3. If not, benchmark WhisperKit streaming.
4. If neither works well, consider embedded whisper.cpp streaming.
5. Keep command backend as fallback.
6. Do not paste unstable partial text.
7. Deduplicate final text.

Acceptance:

```text
First visible partial under 800 ms on warm model.
Final transcript remains stable and deduped.
No per-chunk process spawn.
No temp WAV writes in the main fast path.
```

### Phase 4: Better Endpointing

Goal: stop recording at the right time without cutting words.

Tasks:

1. Add pre-roll and post-roll around VAD endpointing.
2. Benchmark current energy VAD against FluidAudio/Silero/WebRTC VAD.
3. Test noisy rooms and soft speech.
4. Tune silence duration per dictation mode.

Acceptance:

```text
No first-word cutoff.
No last-word cutoff.
No obvious silence hallucinations.
False stop rate acceptable in real room tests.
```

### Phase 5: Privacy And Data Control

Goal: make local-first trust visible.

Already done:

- Storage size breakdown.
- Clear history.
- Clear learning.
- Clear performance logs.
- Privacy Mode redacts new target app metadata.

Next:

1. Add first-run privacy choice.
   - Keep transcript history.
   - Keep metrics only.
   - Privacy Mode.
2. Add data export.
   - settings JSON
   - history JSON
   - correction memory JSON
   - performance logs JSONL
3. Add "do not log target app metadata" separate from full Privacy Mode if needed.
4. Move signing material out of app support.

Acceptance:

```text
User can see, export, and delete local data.
Privacy Mode leaves no new transcript history.
Target app metadata is redacted in Privacy Mode.
No signing secrets live beside user app data.
```

### Phase 6: Resource And Energy Instrumentation

Goal: prove the app stays light.

Tasks:

1. Add Debug resource panel:
   - app RSS
   - model cache size
   - history/log sizes
   - recent average latency
2. Run `powermetrics` manually:

```bash
sudo powermetrics --samplers tasks -n 10 -i 1000
```

3. Measure:
   - idle visible
   - idle hidden
   - 30-second active dictation
   - post-dictation 30 seconds
4. Compare against VoiceInk, Vowen, and Wispr Flow using consistent steps.

Acceptance:

```text
Idle CPU stays at 0%.
Active CPU only spikes during recording/transcription.
App returns to idle after dictation.
Energy report is based on same-method measurements.
```

### Phase 7: UI And Overlay Polish

Goal: make it feel like a premium native utility.

Tasks:

1. Keep the overlay small at idle.
2. Make recording animation audio-reactive but not distracting.
3. Avoid text-heavy overlay states.
4. Improve Settings UI density and visual hierarchy.
5. Build first-run setup:
   - permissions
   - model download
   - shortcut test
   - paste test
6. Add clean copied/manual-paste state.

Acceptance:

```text
Overlay does not block work.
Recording animation reacts to voice tone.
Permissions/model setup is clear without reading README.
Main app feels native and calm.
```

### Phase 8: Production Packaging

Goal: ship a real Mac app, not a local dev bundle.

Tasks:

1. Developer ID certificate.
2. Hardened runtime.
3. Notarization.
4. Proper app versioning.
5. DMG or zip release.
6. Remove local dev signing material from app support.
7. Document permission recovery for users.

Acceptance:

```text
Downloaded app opens without Gatekeeper rejection.
Permissions remain stable across app updates.
No dev signing secrets are stored in user app data.
```

## 11. What We Should Not Build Yet

Do not add these until the core loop is excellent:

- Cloud ASR.
- Cloud LLM rewrite.
- Login/account.
- Subscription.
- Sync.
- Meeting bot.
- Webhooks.
- Command workflows.
- Text expander.
- Team features.
- Fancy AI agent automation.

These are distractions right now. The next win is a faster, more reliable, more polished local dictation loop.

## 12. Immediate Recommended Next Work

The next coding pass should be:

1. Real paste QA matrix and fixes.
2. Real voice benchmark dataset and model decision.
3. True streaming partial transcription investigation.
4. First-run privacy/model/permission setup.
5. Resource panel in Debug.

Best immediate user test:

```text
Open Notes, Chrome, Cursor, and Codex.
Use Hold Control.
Speak 5 short samples and 5 long samples.
Record pasted output and latency from Debug.
Mark which app profile was selected.
```

Best immediate engineering test:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/install_app_bundle.sh
```

Then run real app QA instead of relying only on unit tests.
