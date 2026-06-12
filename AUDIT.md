# Scrivora Audit

Audit date: 2026-06-12

Public product name: Scrivora.

Internal Swift target/module names still use `LocalVoiceFlowCore` and `LocalVoiceFlowApp` in V0.2. The bundle executable also remains `LocalVoiceFlowApp`. This avoids a risky internal rename while preserving the working MVP.

Current bundle ID: `app.localvoiceflow.mvp`.

Current signing identity: `LocalVoiceFlow Development`.

Current install path: `/Applications/Scrivora.app`.

Existing macOS permissions should remain attached to the signed app identity because the bundle ID and signing identity were preserved. If macOS still shows the old display name in System Settings, remove the old entry and grant permissions to `/Applications/Scrivora.app`.

## Verification Commands

Required commands run:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
```

Results:

- `swift test`: passed, 27 tests after V0.2 cleanup/stabilizer/default-model updates.
- `swift build --product LocalVoiceFlowApp`: passed. `Package.swift` and `Package.resolved` point at `https://github.com/FluidInference/FluidAudio.git` version `0.15.2`. The official GitHub dependency fetch stalled in this local session, so the workspace uses an ignored SwiftPM mirror at `Vendor/FluidAudio`; this replaces the earlier broken `/tmp/FluidAudio` mirror.
- `Scripts/package_app_bundle.sh`: passed and now produces `.build/Scrivora.app`, signed with `LocalVoiceFlow Development`.

Additional real ASR verification:

```bash
brew install whisper-cpp
Scripts/download_whisper_model.sh base.en-q5_1
say -v Samantha "hello local voice flow this is a local dictation test" -o /tmp/localvoiceflow-test.aiff
afconvert -f WAVE -d LEI16@16000 /tmp/localvoiceflow-test.aiff /tmp/localvoiceflow-test.wav
whisper-cli -m "$HOME/Library/Application Support/LocalVoiceFlow/Models/ggml-base.en-q5_1.bin" -f /tmp/localvoiceflow-test.wav -otxt -of /tmp/localvoiceflow-direct -nt -np
LOCALVOICEFLOW_WHISPER_CLI=/opt/homebrew/bin/whisper-cli LOCALVOICEFLOW_WHISPER_MODEL="$HOME/Library/Application Support/LocalVoiceFlow/Models/ggml-base.en-q5_1.bin" LOCALVOICEFLOW_TEST_WAV=/tmp/localvoiceflow-test.wav swift test --filter WhisperCppIntegrationTests
LOCALVOICEFLOW_WHISPER_SERVER=/opt/homebrew/bin/whisper-server LOCALVOICEFLOW_WHISPER_MODEL="$HOME/Library/Application Support/LocalVoiceFlow/Models/ggml-base.en-q5_1.bin" LOCALVOICEFLOW_TEST_WAV=/tmp/localvoiceflow-test.wav swift test --filter WhisperCppIntegrationTests/whisperCppServerEngineTranscribesConfiguredAudioFile
```

Results:

- Direct `whisper-cli` transcribed: `Hello local voice flow this is a local dictation test.`
- Direct `whisper-cli` wall time on the generated WAV: about `0.71s`.
- Swift `WhisperCppCLIEngine` integration test passed.
- Swift `WhisperCppServerEngine` integration test passed.
- A warm manual `whisper-server` request returned in about `0.11s` after model load.

Additional FluidAudio Parakeet verification:

```bash
say -v Samantha "hello local voice flow this is a local dictation test using parakeet" -o /tmp/localvoiceflow-parakeet-test.aiff
afconvert -f WAVE -d LEI16@16000 /tmp/localvoiceflow-parakeet-test.aiff /tmp/localvoiceflow-parakeet-test.wav
Vendor/FluidAudio/.build/release/fluidaudiocli transcribe /tmp/localvoiceflow-parakeet-test.wav --model-version v3 --model-dir "$HOME/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3"
Scripts/download_fluidaudio_model.sh v2
```

Results:

- FluidAudio loaded Parakeet V3 from `~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v3`.
- The command transcribed: `Hello local voice flow this is a local dictation test using Parakeet.`
- FluidAudio reported `4.00s` audio, `0.16s` processing time, `24.46x` RTFx, and `0.933` confidence.
- FluidAudio Parakeet V2 was also verified after repairing an interrupted cache. It downloaded to `~/Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v2`, transcribed the same synthetic sample correctly, and reported about `0.12s` processing time / `33.88x` RTFx. First load may compile CoreML models and take longer.
- `python3 -m py_compile Scripts/benchmark_asr.py` passed.

## What Is Fully Working

- Swift package builds.
- App target links.
- App bundle script creates a runnable `.app` wrapper with `NSMicrophoneUsageDescription`.
- Homebrew `whisper-cpp` install works on this Mac.
- `ggml-base.en-q5_1.bin` downloads into `~/Library/Application Support/LocalVoiceFlow/Models`.
- Real local `whisper-cli` transcription works with the downloaded model.
- Swift `WhisperCppCLIEngine` works with real local Whisper.
- Swift `WhisperCppServerEngine` works with real local Whisper and keeps the model resident in a local helper process.
- FluidAudio Parakeet V3/V2 models are present in the model catalog.
- `FluidAudioBatchASREngine` loads Parakeet models in-process from FluidAudio's cache and keeps the model resident across dictations.
- The Parakeet path transcribes the app's in-memory 16 kHz samples directly and does not write microphone audio to a temp WAV.
- Parakeet models can be downloaded from the app settings or through `Scripts/download_fluidaudio_model.sh`.
- Interrupted Parakeet downloads are now detected and retried by removing incomplete FluidAudio cache directories before download.
- Audio ring buffer, VAD, silence detector, chunk scheduler, text cleanup, history/settings storage, and model defaults are covered by tests.
- The default selected ASR model now points to Parakeet V2 English for Instant mode.
- Hold Control and Double-tap Control trigger modes are implemented while preserving the global shortcut path.
- Parakeet pseudo-streaming partials are implemented on a throttled rolling in-memory audio window. True FluidAudio streaming/EOU is still future work.
- Deterministic cleanup now includes artifact removal, repetition reduction, dictation commands, punctuation formatting, user dictionary replacements, and final normalization.
- Performance logs are appended locally to `Logs/dictation-performance.jsonl` without transcript text.

## What Is Partially Working

- Menu bar app shell exists and compiles, but needs interactive UI verification after permissions are granted.
- Microphone recording uses `AVAudioEngine` and feeds 16 kHz mono samples into the ring buffer.
- VAD is used in the app loop to switch listening state and trigger silence auto-stop.
- Latency metrics are recorded for hotkey-to-recording, recording-to-speech, model load, warmup, ASR, cleanup, paste, and stop-speaking-to-inserted text, but interactive end-to-end metrics still need a live dictation run.
- Clipboard paste fallback exists, but Notes/TextEdit/Chrome paste behavior must be manually verified with Accessibility permission granted.
- Accessibility permission prompting is implemented with `AXIsProcessTrustedWithOptions`, but the app does not yet deep-link to settings from the visible UI.
- Direct accessibility insertion is best-effort and may fail for many text fields; clipboard paste remains the practical insertion path.
- FluidAudio Parakeet pseudo-streaming partials are implemented, but they are rolling-window batch partials, not true streaming/EOU.

## What Is Mocked

- `MockASREngine` remains for tests and explicit `LOCALVOICEFLOW_USE_MOCK_ASR=1` UI-only runs.
- Mock ASR is no longer the default real app path.
- LLM post-processing is protocol-only; no local LLM backend is implemented.

## What Was Missing Before This Pass

- Default settings pointed to an unimplemented WhisperKit model.
- There was no setting for an explicit model file path.
- The only real backend spawned `whisper-cli` per transcription.
- The app did not keep a local Whisper model resident.
- There was no integration test proving the Swift ASR engine could transcribe with a real model.
- Model setup required source build tooling and failed when `cmake` was absent.
- Hotkey-to-recording and recording-to-speech metrics were declared but not recorded.
- There was no in-process Apple Silicon ASR backend using in-memory audio.

## What Still Blocks Real-World Use

- Full Xcode is not installed/selected on this Mac; only Command Line Tools are active. Production signing, notarization, and Xcode UI debugging remain unverified.
- Interactive microphone permission and Accessibility permission grants require user action.
- Global hotkey behavior outside the app still needs a live app/manual test.
- Paste into Notes/TextEdit/Chrome still needs manual verification after Accessibility is granted.
- True streaming partial transcription is not implemented. The command and server engines return final text only; Parakeet partials are pseudo-streaming rolling-window batch calls.
- The whisper.cpp fallback still writes a temporary WAV before final ASR. The FluidAudio Parakeet path does not.
- The persistent helper is local-only but still an HTTP server bound to `127.0.0.1`; this is acceptable for MVP latency, but production should harden lifecycle, port selection, and failure recovery.
- FluidAudio increases build size/time because SwiftPM compiles the full package, not just ASR.

## Exact Fixes Needed Next

Priority fixes implemented:

- Default ASR now uses `fluidaudio-parakeet-v2`.
- Added explicit model path storage.
- Added model runtime fields for `whisper-cli`, `whisper-server`, and persistent-server preference.
- Added `Scripts/download_whisper_model.sh`.
- Added `Scripts/download_fluidaudio_model.sh`.
- Updated `Scripts/bootstrap_whisper_cpp.sh` to use Homebrew `whisper-cpp` when available.
- Added `WhisperCppServerEngine`.
- Added `FluidAudioBatchASREngine` for Parakeet V3/V2 in-process batch ASR.
- Cached the loaded ASR engine across dictations.
- Added real local Whisper integration tests.
- Added FluidAudio benchmark support to `Scripts/benchmark_asr.py`.
- Added timing metrics for hotkey-to-recording, recording-to-speech, first partial, final ASR, cleanup, paste, and total stop-to-inserted text.
- Added Scrivora public app naming while keeping internal target names unchanged.
- Added `.build/Scrivora.app` packaging and `/Applications/Scrivora.app` install path.
- Added `BENCHMARKS_LOCAL.md` and `PASTE_QA.md`.

Remaining exact fixes:

1. Run the actual app interactively and grant microphone/accessibility permissions.
2. Verify global hotkey start/stop from Notes, TextEdit, Chrome, and another non-app foreground context.
3. Verify clipboard paste and restoration across Notes, TextEdit, Chrome, and Terminal.
4. Add visible model readiness status for loaded Parakeet/whisper-server/CLI backend.
5. Implement real partials through FluidAudio streaming/EOU, WhisperKit streaming, or embedded whisper.cpp streaming; do not spawn `whisper-cli` for frequent partial chunks.
6. Replace the energy-only VAD with FluidAudio Silero VAD or another neural/WebRTC VAD after measuring false-stop behavior.
7. Keep the transcript on the clipboard when paste fails, but add a clearer "copied, paste manually" UI state.
8. Investigate splitting or vendoring only the needed FluidAudio ASR surface if release build times or app size become unacceptable.
