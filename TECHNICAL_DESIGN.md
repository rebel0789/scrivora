# Scrivora Technical Design

## Architecture

Scrivora is split into a pure Swift core library and a macOS SwiftUI app target.

- `LocalVoiceFlowCore`: pipeline logic, model metadata, settings/history stores, text cleanup, diagnostics, ASR/LLM protocols, and testable algorithms.
- `LocalVoiceFlowApp`: SwiftUI menu bar app, AppKit permission and insertion services, AVAudioEngine capture, global hotkey registration, and views.

The public product name is Scrivora. Swift target and module names remain `LocalVoiceFlowCore` and `LocalVoiceFlowApp` in V0.2 to avoid a risky internal rename while preserving the working app.

This keeps model/runtime-specific code behind protocols and keeps most behavior testable with `swift test`.

## Pipeline

```text
Trigger mode
-> AudioCaptureService
-> AudioConverter16kMono
-> AudioRingBuffer
-> VoiceActivityDetector
-> SilenceDetector
-> ChunkScheduler
-> ASREngine or pseudo-streaming Parakeet partial loop
-> PartialTranscriptStabilizer
-> FinalTranscriptBuilder
-> TextPostProcessor
-> TextInsertionService
-> PerformanceLogger
```

## ASR Boundary

`ASREngine` exposes:

- `loadModel(_:)`
- `warmup()`
- `transcribe(chunk:)`
- `transcribeFinal(buffer:)`
- `unload()`
- `isLoaded`
- `modelInfo`

V0.2 default is FluidAudio Parakeet V2 in-process batch ASR with pseudo-streaming partials. Persistent `whisper-server` remains compatible fallback and `whisper-cli` remains emergency fallback. True streaming/EOU should be implemented through FluidAudio streaming APIs when benchmarked and stable.

## LLM Boundary

`LLMEngine` is optional and only used after final ASR or stable long-dictation commits. The default MVP uses `FastTextFormatter` and command replacements only. V1 can add a llama.cpp-backed `LocalLLMEngine`.

## Storage

Use local JSON files under:

`~/Library/Application Support/LocalVoiceFlow`

This storage path remains unchanged in V0.2 so existing settings, history, and downloaded whisper.cpp models are preserved during the public rename to Scrivora.

Subfolders:

- `Models`
- `History`
- `Logs`
- `Settings`

No raw audio is stored by default. Temporary WAV files for command-line backend testing are written to the system temporary directory and deleted after transcription.

## Text Insertion

Insertion strategy:

1. Try accessibility insertion only when the focused element supports text value updates.
2. Fall back to clipboard paste.
3. Preserve existing pasteboard items.
4. Set transcript as plain text.
5. Simulate Command-V.
6. Restore previous pasteboard items after a short delay if configured.

The default MVP should prefer reliability over aggressive direct insertion because web editors, secure fields, Terminal, Electron apps, and custom text components vary widely.

## Permissions

- Microphone: request through AVFoundation capture authorization.
- Accessibility: check `AXIsProcessTrustedWithOptions`; show recovery action that opens System Settings.
- Hotkeys: register through Carbon global hotkey APIs for the MVP.
- Control triggers: register through a listen-only CGEvent tap and require Accessibility permission.

## Performance Metrics

Record:

- Hotkey to recording start.
- Recording start to speech detected.
- Speech end to final ASR complete.
- Final ASR to cleanup complete.
- Cleanup to paste complete.
- Total stop-speaking to inserted text.
- Model load time.
- Model warmup time.
- First partial latency.
- Paste method.

One JSONL record per dictation is appended to `Logs/dictation-performance.jsonl`. Transcript text is not logged.

Metrics are kept local and surfaced in the debug/performance view.

## UI Direction

The UI should be quiet, precise, and native:

- Menu bar first.
- Compact floating overlay.
- Light/dark mode.
- Neutral macOS material surfaces.
- One restrained blue accent for active dictation.
- Green only for small ready/live status indicators.
- Keyboard-first controls.
- No copied Wispr Flow naming, shapes, icons, animations, or copy.

## Verification

Automated:

- `swift test`

Manual:

- Launch app from Xcode or `swift run LocalVoiceFlowApp`.
- Grant microphone and accessibility permissions.
- Confirm menu bar extra appears.
- Configure shortcut.
- Start and stop recording.
- Confirm final text insertion into Notes, Safari/Chrome text field, Slack/Discord, VS Code/Cursor, and Terminal where possible.
- Confirm clipboard restoration.
- Toggle privacy mode and verify history does not grow.
- Disconnect network after model download and verify dictation still works.
