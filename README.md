# Scrivora

Scrivora — speak, and your Mac writes.

Private dictation for Mac. Local AI. No subscription.

Scrivora is a native macOS, local-first dictation assistant. It is built as a Swift Package with a macOS SwiftUI menu bar executable and a tested core library. The repository and Swift module names still use `LocalVoiceFlow` internally while the public product name is Scrivora.

The current MVP code includes:

- Menu bar app shell.
- Global shortcut registration plus Hold Control and Double-tap Control trigger modes.
- Microphone permission check/request.
- Accessibility permission check/request.
- AVAudioEngine capture into 16 kHz mono samples.
- In-memory audio ring buffer.
- Energy VAD and silence endpointing.
- Rolling chunk scheduler.
- Floating dictation overlay.
- ASR/LLM protocols.
- FluidAudio Parakeet V2/V3 backend for fast Apple Silicon local ASR.
- Pseudo-streaming Parakeet partial transcription on a rolling in-memory window.
- Local whisper.cpp-compatible server and command backends as fallback.
- Deterministic text cleanup, dictation commands, and app-aware output profiles.
- Accessibility insertion attempt plus clipboard paste fallback.
- Local JSON settings/history stores.
- Local model catalog and model storage.
- Debug/performance metrics and local JSONL latency logs.
- Swift 6 `Testing` coverage for core pipeline behavior.

## Requirements

- macOS 14 or later.
- Swift 6.1+.
- Xcode 16+ recommended for a proper app bundle, microphone usage description, signing, and notarization.
- Command Line Tools are enough for `swift test` and `swift run`, but full Xcode is needed for production packaging.

## Build And Test

```bash
swift test
swift build --product LocalVoiceFlowApp
```

Run the app shell:

```bash
swift run LocalVoiceFlowApp
```

For UI-only testing without a local ASR model:

```bash
LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp
```

## App Bundle

Create a local signed development app bundle:

```bash
Scripts/package_app_bundle.sh
open .build/Scrivora.app
```

The bundle script writes an `Info.plist` with microphone usage text and signs ad-hoc when `codesign` is available.

For day-to-day testing with microphone and Accessibility permissions, install the app to a stable path first:

```bash
Scripts/install_app_bundle.sh
open "/Applications/Scrivora.app"
```

Grant microphone and Accessibility permissions to `/Applications/Scrivora.app`, not the temporary `.build` copy. The bundle ID remains `app.localvoiceflow.mvp` and the local development signing identity remains `LocalVoiceFlow Development` to keep the macOS permission identity stable during the public rename.

The packaging script now creates and uses a local self-signed code-signing identity named `LocalVoiceFlow Development` when no Apple Developer ID identity is available. This gives macOS privacy permissions a stable designated requirement across rebuilds:

```text
identifier "app.localvoiceflow.mvp" and certificate root = <LocalVoiceFlow Development certificate>
```

Vowen and Wispr Flow avoid repeated permission prompts by using notarized Developer ID signatures. The local development identity is the closest equivalent for this unsigned MVP; for production, replace it with a real Developer ID Application certificate.

## Local ASR Setup

### Recommended: FluidAudio Parakeet

Parakeet is the recommended local accuracy path for Apple Silicon testing. It keeps the model loaded in-process, transcribes the app's in-memory 16 kHz samples, and does not write app microphone audio to disk.

Download/select Parakeet V2 from the app:

1. Open Scrivora.
2. Open Settings.
3. In ASR Models, click `Download` on `Parakeet V2 English`.
4. Leave the app open while CoreML downloads and compiles the model.
5. Select `Parakeet V2 English`.

Or download from the terminal:

```bash
Scripts/download_fluidaudio_model.sh v2
```

For V3 multilingual:

```bash
Scripts/download_fluidaudio_model.sh v3
```

If a Parakeet download was interrupted, run the same command again. The script checks the FluidAudio cache and removes an incomplete model folder before retrying.

The script builds the FluidAudio CLI from an ignored `Vendor/FluidAudio` checkout if `fluidaudiocli` is not already installed. That checkout is only a local dependency/build cache.

Parakeet models are stored by FluidAudio in:

```text
~/Library/Application Support/FluidAudio/Models
```

V0.2 defaults to `Parakeet V2 English` for Instant mode. V3 remains available as the Balanced multilingual option.

### Fallback: whisper.cpp

The MVP runner includes two local whisper.cpp-compatible backends:

- Preferred: `whisper-server`, a local helper bound to `127.0.0.1` that keeps the model loaded.
- Fallback: `whisper-cli`, a command backend that launches per transcription.

Install or build whisper.cpp, then point Scrivora to the executable path in settings if auto-detection does not find Homebrew paths.

Bootstrap whisper.cpp and a GGML model:

```bash
Scripts/bootstrap_whisper_cpp.sh base.en-q5_1
```

Only download a model:

```bash
Scripts/download_whisper_model.sh base.en-q5_1
```

Expected executable paths:

- `/opt/homebrew/bin/whisper-cli`
- `/opt/homebrew/bin/whisper-server`
- `/usr/local/bin/whisper-cli`
- `/usr/local/bin/whisper-server`
- `/opt/homebrew/bin/whisper-cpp`
- `/usr/local/bin/whisper-cpp`

The persistent `whisper-server` bridge keeps the model loaded between utterances. The CLI bridge remains as emergency fallback. The FluidAudio Parakeet backend is now the preferred low-latency in-process path; whisper.cpp remains useful for compatibility and fallback.

For the default app path, use:

- Whisper binary: `/opt/homebrew/bin/whisper-cli`
- Whisper server: `/opt/homebrew/bin/whisper-server`
- Model path: leave blank if the selected model was downloaded into `~/Library/Application Support/LocalVoiceFlow/Models`
- Default model file: `ggml-base.en-q5_1.bin`

For better English with accents, casual speech, and imperfect microphone input, use the `small.en-q5_1` model:

```bash
Scripts/download_whisper_model.sh small.en-q5_1
```

Then select `Accurate` in the Models section. `base.en-q5_1` is fast, but it is noticeably worse for slang, accent variation, and noisy speech.

## Benchmark Real Voice Samples

Prompts for human voice testing live in:

```text
BenchmarkSamples/reading-prompts.csv
```

Record benchmark samples:

```bash
Scripts/record_benchmark_samples.sh
```

Compare Whisper and Parakeet on the manifest:

```bash
Scripts/benchmark_asr.py \
  --manifest BenchmarkSamples/manifest.csv \
  --include-fluidaudio \
  --fluidaudio-model-version v2 \
  --fluidaudio-model-version v3 \
  --whisper-model ggml-small.en-q5_1.bin
```

See `ACCURACY_TEST.md` for the live app test matrix and what to report when an app-specific profile is wrong.

## App-Aware Output Profiles

By default, Cleanup uses `Automatic` output profile routing:

- Coding and terminal apps use `Pragmatic` cleanup.
- AI agent/chat apps use `Agent` cleanup.
- Mail clients use `Email` cleanup.
- Notes, TextEdit, browsers, and unknown apps use `General` cleanup.

You can override this in Settings → Cleanup → Output profile. Browser tab-specific routing is not implemented yet; Chrome/Safari/Arc/Firefox are treated as browsers unless a future Accessibility or browser-title integration identifies Gmail, Docs, or another site.

## Real ASR Smoke Test

```bash
say -v Samantha "hello local voice flow this is a local dictation test" -o /tmp/localvoiceflow-test.aiff
afconvert -f WAVE -d LEI16@16000 /tmp/localvoiceflow-test.aiff /tmp/localvoiceflow-test.wav
LOCALVOICEFLOW_WHISPER_SERVER=/opt/homebrew/bin/whisper-server \
LOCALVOICEFLOW_WHISPER_CLI=/opt/homebrew/bin/whisper-cli \
LOCALVOICEFLOW_WHISPER_MODEL="$HOME/Library/Application Support/LocalVoiceFlow/Models/ggml-base.en-q5_1.bin" \
LOCALVOICEFLOW_TEST_WAV=/tmp/localvoiceflow-test.wav \
swift test --filter WhisperCppIntegrationTests
```

## Data Locations

Local app data:

```text
~/Library/Application Support/LocalVoiceFlow
```

Subfolders:

- `Models`
- `Settings`
- `History`
- `Logs`

Raw audio is not stored by default.

## Current Limitations

- The SwiftPM app is a working development runner, not a notarized production `.app`.
- WhisperKit SDK integration is documented in `RESEARCH.md` and `TECHNICAL_DESIGN.md` but not linked into the package yet, to keep the core build independent of a full Xcode install.
- FluidAudio Parakeet pseudo-streaming partials are implemented. True FluidAudio streaming/EOU remains future work.
- First Parakeet load can be slow because CoreML compiles the model; warm transcription should be much faster.
- The whisper.cpp CLI/server fallback still writes a temporary WAV for final ASR. The Parakeet path uses in-memory samples.
- Direct accessibility insertion is best-effort. Clipboard paste remains the reliable path across browsers and Electron apps.
- Clipboard restoration is configurable and defaults to 600 ms after paste.
- App-aware cleanup currently uses foreground app name and bundle ID only. Browser tab/site-specific routing is not production-ready yet.

## Local Improvement Loop

Scrivora now has a local correction-memory loop inspired by agent systems that improve through durable memory and reusable skills:

1. Dictate normally.
2. Open History.
3. Click `Correct & Learn` on a transcript.
4. Edit the transcript to what you meant.
5. Click `Learn Correction`.

The app stores the correction locally in:

```text
~/Library/Application Support/LocalVoiceFlow/Learning/corrections.json
```

When the correction is safe to generalize, Scrivora adds a local user dictionary rule, such as:

- `UR` → `UI`
- `pnchuations` → `punctuations`
- `text edit` → `TextEdit`

This is not model retraining. Parakeet and whisper.cpp are still static ASR models. The improvement curve comes from local post-ASR adaptation: personal vocabulary, app-specific cleanup, correction history, and future per-app rules. Audio is still not saved by default.

## Manual QA

1. Run `swift test`.
2. Run `LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp`.
3. Confirm the menu bar item appears.
4. Open Settings and verify Setup, Dictation, Models, Cleanup, History, Privacy, Debug, and About sections.
5. Grant microphone and accessibility permissions.
6. Toggle dictation from the menu, hold Control, double-tap Control, or use the global shortcut mode.
7. Confirm the floating overlay appears.
8. Confirm final text is copied/pasted in mock mode.
9. Disable history or enable Privacy Mode and verify new transcripts are not stored.
10. Download/select Parakeet V2 or configure whisper.cpp fallback, then test real local transcription in Notes, TextEdit, and Chrome.

## Quickstart

1. Build the app:
   ```bash
   swift build --product LocalVoiceFlowApp
   ```
2. Package the app:
   ```bash
   Scripts/package_app_bundle.sh
   ```
3. Install to Applications:
   ```bash
   Scripts/install_app_bundle.sh
   ```
4. Open `/Applications/Scrivora.app`.
5. Grant Microphone permission.
6. Grant Accessibility permission.
7. Download/select `Parakeet V2 English`.
8. Open Notes.
9. Hold Control or use the shortcut.
10. Speak naturally.
11. Release Control or stop recording.
12. Confirm text pastes and check debug latency.
