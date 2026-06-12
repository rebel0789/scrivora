# LocalVoiceFlow

LocalVoiceFlow is a native macOS, local-first dictation assistant. It is built as a Swift Package with a macOS SwiftUI menu bar executable and a tested core library.

The current MVP code includes:

- Menu bar app shell.
- Global shortcut registration. The default is a quick standalone Control key tap.
- Microphone permission check/request.
- Accessibility permission check/request.
- AVAudioEngine capture into 16 kHz mono samples.
- In-memory audio ring buffer.
- Energy VAD and silence endpointing.
- Rolling chunk scheduler.
- Floating dictation overlay.
- ASR/LLM protocols.
- FluidAudio Parakeet batch backend for fast Apple Silicon local ASR.
- Local whisper.cpp-compatible server and command backends as fallback.
- Deterministic text cleanup and dictation commands.
- Accessibility insertion attempt plus clipboard paste fallback.
- Local JSON settings/history stores.
- Local model catalog and model storage.
- Debug/performance metrics model.
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

Create a local unsigned/ad-hoc app bundle:

```bash
Scripts/package_app_bundle.sh
open .build/LocalVoiceFlowApp.app
```

The bundle script writes an `Info.plist` with microphone usage text and signs ad-hoc when `codesign` is available.

For day-to-day testing with microphone and Accessibility permissions, install the app to a stable path first:

```bash
Scripts/install_app_bundle.sh
open "/Applications/LocalVoiceFlow.app"
```

Grant microphone and Accessibility permissions to `/Applications/LocalVoiceFlow.app`, not the temporary `.build` copy. This matters because the SwiftPM bundle is ad-hoc signed on this Mac, so rebuilding the `.build` copy can invalidate macOS privacy permissions.

The packaging script now creates and uses a local self-signed code-signing identity named `LocalVoiceFlow Development` when no Apple Developer ID identity is available. This gives macOS privacy permissions a stable designated requirement across rebuilds:

```text
identifier "app.localvoiceflow.mvp" and certificate root = <LocalVoiceFlow Development certificate>
```

Vowen and Wispr Flow avoid repeated permission prompts by using notarized Developer ID signatures. The local development identity is the closest equivalent for this unsigned MVP; for production, replace it with a real Developer ID Application certificate.

## Local ASR Setup

### Recommended: FluidAudio Parakeet

Parakeet is the recommended local accuracy path for Apple Silicon testing. It keeps the model loaded in-process, transcribes the app's in-memory 16 kHz samples, and does not write app microphone audio to disk.

Download Parakeet V3 from the app:

1. Open LocalVoiceFlow.
2. Open Settings.
3. In ASR Models, click `Download` on `Parakeet V3`.
4. Leave the app open while CoreML downloads and compiles the model.
5. Select `Parakeet V3`.

Or download from the terminal:

```bash
Scripts/download_fluidaudio_model.sh v3
```

For V2 English:

```bash
Scripts/download_fluidaudio_model.sh v2
```

If a Parakeet download was interrupted, run the same command again. The script checks the FluidAudio cache and removes an incomplete model folder before retrying.

The script builds the FluidAudio CLI from an ignored `Vendor/FluidAudio` checkout if `fluidaudiocli` is not already installed. That checkout is only a local dependency/build cache.

Parakeet models are stored by FluidAudio in:

```text
~/Library/Application Support/FluidAudio/Models
```

Use `Parakeet V2 English` if V3 is less accurate for your English dictation. V3 is multilingual; V2 is English-only and can be better for English recall.

### Fallback: whisper.cpp

The MVP runner includes two local whisper.cpp-compatible backends:

- Preferred: `whisper-server`, a local helper bound to `127.0.0.1` that keeps the model loaded.
- Fallback: `whisper-cli`, a command backend that launches per transcription.

Install or build whisper.cpp, then point LocalVoiceFlow to the executable path in settings if auto-detection does not find Homebrew paths.

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

The persistent `whisper-server` bridge keeps the model loaded between utterances. The CLI bridge remains as fallback. The FluidAudio Parakeet backend is now the preferred low-latency in-process path; whisper.cpp remains useful for comparison and fallback.

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

Record benchmark samples:

```bash
Scripts/record_benchmark_samples.sh
```

Compare Whisper and Parakeet on the manifest:

```bash
Scripts/benchmark_asr.py \
  --manifest BenchmarkSamples/manifest.csv \
  --include-fluidaudio \
  --fluidaudio-model-version v3 \
  --whisper-model ggml-small.en-q5_1.bin
```

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
- FluidAudio Parakeet is implemented as a final/batch backend. Real streaming partial transcription is still future work.
- First Parakeet load can be slow because CoreML compiles the model; warm transcription should be much faster.
- The whisper.cpp CLI/server fallback still writes a temporary WAV for final ASR. The Parakeet path uses in-memory samples.
- Direct accessibility insertion is best-effort. Clipboard paste remains the reliable path across browsers and Electron apps.

## Manual QA

1. Run `swift test`.
2. Run `LOCALVOICEFLOW_USE_MOCK_ASR=1 swift run LocalVoiceFlowApp`.
3. Confirm the menu bar item appears.
4. Open Settings and verify Setup, Dictation, Models, Cleanup, History, Privacy, Debug, and About sections.
5. Grant microphone and accessibility permissions.
6. Toggle dictation from the menu or by quickly tapping the Control key by itself.
7. Confirm the floating overlay appears.
8. Confirm final text is copied/pasted in mock mode.
9. Disable history or enable Privacy Mode and verify new transcripts are not stored.
10. Download/select Parakeet V3 or configure whisper.cpp fallback, then test real local transcription in Notes, TextEdit, and Chrome.
