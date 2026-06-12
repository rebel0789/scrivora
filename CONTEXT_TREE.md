# LocalVoiceFlow Context Tree

Last updated: 2026-06-12

Purpose: keep product, architecture, ASR, UX, and competitor research in one map so future implementation does not drift into random features before the core dictation loop is excellent.

Primary external reference reviewed:

- Vowen docs dump: https://docs.vowen.ai/llms-full.txt

- VoiceInk repository reviewed: https://github.com/Beingpax/VoiceInk.git
- FluidAudio docs/repo reviewed: https://docs.fluidinference.com/llms.txt and https://github.com/FluidInference/FluidAudio

## North Star

LocalVoiceFlow should feel like an instant local macOS dictation tool:

```text
shortcut
-> start recording immediately
-> detect speech and silence
-> transcribe locally
-> clean deterministic artifacts
-> paste or copy reliably
-> show what happened and how long it took
```

Do not expand into command workflows, sync, meetings, or cloud enhancement until this loop is fast, accurate, and reliable across real target apps.

## Competitor Signals From Vowen

### Useful Signals

- They split the product into clear lanes: transcription, optional AI enhancement, auto-paste, command mode, notes, snippets, dictionary, workflows, and sync.
- They treat text delivery as a first-class setting. Paste is fast and default; direct insertion exists for apps or keyboard layouts where paste fails.
- They make shortcuts ergonomic: hold-to-record, hands-free toggle, modifier-only shortcuts, left/right modifier variants, mouse buttons, and conflict resolution when shortcut prefixes overlap.
- They use per-shortcut behavior to separate raw dictation from polished dictation.
- They expose per-app tone/profile concepts so output can be raw in coding tools and more polished in email or notes.
- They document permission recovery explicitly because macOS Accessibility state can be confusing after granting access.
- They position Parakeet as the Apple Silicon streaming/preview lane and Whisper as a mature local/cloud accuracy lane.
- They acknowledge common Whisper failure modes: silence hallucinations, first/last word cutoffs, repetition, and vocabulary errors.
- They keep model download separate from app install so the app stays small and the user chooses the model.

### Signals To Avoid Copying Now

- Do not copy cloud transcription or BYO cloud AI provider flows into the MVP. LocalVoiceFlow's current promise is local-only by default.
- Do not add command mode, file conversion, webhooks, sync, meeting notes, or text expander before dictation quality is stable.
- Do not build a pricing/pro feature architecture now.
- Do not make AI cleanup mandatory. Raw/local dictation must stay fast and trustworthy.
- Do not use competitor wording, UI identity, icon style, or onboarding copy.

## Current LocalVoiceFlow Truth

### Working Core

- Native Swift Package with `LocalVoiceFlowCore` and `LocalVoiceFlowApp`.
- Menu bar app and settings window.
- Microphone and Accessibility permission checks.
- Control Tap global shortcut through a CGEvent tap.
- AVAudioEngine capture converted into 16 kHz mono samples.
- In-memory ring buffer.
- Energy-based VAD and silence endpointing.
- Persistent `whisper-server` backend that keeps a whisper.cpp model loaded.
- `whisper-cli` fallback backend.
- FluidAudio Parakeet V3/V2 batch backend that keeps the model loaded in-process and transcribes in-memory samples.
- Deterministic cleanup for punctuation commands, artifacts, replacements, and basic formatting.
- Clipboard-first paste fallback that leaves the final transcript on the clipboard.
- Local JSON settings and history.
- Local model catalog and downloader for whisper.cpp GGML files.
- Latency metrics surfaced in DebugPerformanceView.

### Partial Or Not Real Yet

- Real partial transcription is not implemented. `transcribe(chunk:)` returns empty partials for whisper.cpp and FluidAudio batch backends.
- Chunk scheduler exists, but chunks are not being sent to a streaming ASR backend.
- VAD is energy-based only. It is useful for MVP endpointing but weaker than Silero/WebRTC/neural VAD in noisy rooms.
- Clipboard restoration is intentionally deprioritized because reliable manual paste fallback matters more right now.
- Direct accessibility insertion is not a reliable path across Chrome/Electron/web editors.
- Model readiness is implied by errors/settings, not shown as a clean product state.
- The UI is functional but not yet the calm native command surface users expect from a daily tool.

## Product Scope Tree

```text
LocalVoiceFlow
├── Core dictation loop
│   ├── shortcut
│   │   ├── Control Tap toggle
│   │   ├── future hold-to-record
│   │   ├── future hands-free shortcut
│   │   └── future conflict resolver for shared prefixes
│   ├── recording
│   │   ├── microphone permission
│   │   ├── selected input device
│   │   ├── 16 kHz mono capture
│   │   ├── ring buffer
│   │   └── no audio saved by default
│   ├── endpointing
│   │   ├── current energy VAD
│   │   ├── silence duration setting
│   │   ├── pre-roll to avoid first-word cutoff
│   │   ├── post-roll to avoid last-word cutoff
│   │   └── future neural/WebRTC VAD benchmark
│   ├── ASR
│   │   ├── whisper.cpp server fallback
│   │   ├── whisper.cpp CLI fallback
│   │   ├── Parakeet batch backend
│   │   ├── Parakeet streaming benchmark lane
│   │   ├── WhisperKit benchmark lane
│   │   └── future embedded backend for in-memory audio and streaming partials
│   ├── cleanup
│   │   ├── strip non-speech artifacts
│   │   ├── punctuation and line commands
│   │   ├── replacements / threads
│   │   ├── user dictionary
│   │   ├── filler removal
│   │   └── optional local LLM cleanup later
│   ├── delivery
│   │   ├── copy final transcript first
│   │   ├── auto-paste when Accessibility trusted
│   │   ├── leave clipboard fallback when paste fails
│   │   ├── future direct typing mode
│   │   └── future per-app insertion policy
│   └── observability
│       ├── hotkey to recording
│       ├── recording to speech
│       ├── speech end to ASR final
│       ├── ASR to cleanup
│       ├── cleanup to paste
│       ├── speech end to inserted text
│       └── model load/warmup
├── Model setup
│   ├── bundled app stays small
│   ├── user-initiated model downloads
│   ├── whisper.cpp bootstrap script
│   ├── model manager UI
│   ├── model readiness indicator
│   ├── corruption detection / re-download
│   └── benchmark-driven recommendations
├── UX surface
│   ├── menu bar quick controls
│   ├── compact recording overlay
│   ├── first-run setup checklist
│   ├── permissions recovery screen
│   ├── model selection screen
│   ├── last transcript and copy fallback
│   ├── history
│   └── debug performance screen
├── Personalization
│   ├── dictionary
│   ├── phrase replacements
│   ├── app-specific raw/polished mode
│   ├── shortcut-specific cleanup mode
│   └── local prompt-based cleanup later
└── Deferred expansion
    ├── cloud ASR: out of scope
    ├── cloud LLM: out of scope
    ├── command mode: later
    ├── meeting notes: later
    ├── workflows/webhooks: later
    ├── sync/account/subscription: out of scope for this product direction
    └── text expander: later only if dictation retention proves strong
```

## ASR Decision Tree

```text
Need best usable MVP today?
└── Use FluidAudio Parakeet V3 if downloaded; keep whisper.cpp small.en-q5_1 as fallback.

Need better accuracy without cloud?
├── Benchmark whisper.cpp medium/large/turbo quantized.
├── Benchmark WhisperKit Core ML large-v3-turbo if full Xcode flow is available.
└── Benchmark Parakeet V3/V2 on Apple Silicon with real microphone samples.

Need real partials / live preview?
├── Preferred: backend with streaming API and resident model.
├── Candidate A: WhisperKit streaming.
├── Candidate B: Parakeet CoreML/MLX if packaging and startup are acceptable.
├── Candidate C: embedded whisper.cpp streaming/C API.
└── Avoid: spawning whisper-cli for every chunk.

Need lowest latency?
├── Keep model loaded before hotkey.
├── Avoid disk WAV writes in production backend.
├── Avoid per-utterance process spawn.
├── Use pre-roll and endpointing to reduce re-records.
└── Measure real user voice, not only `say` samples.
```

## Parakeet Position

Parakeet should not be abandoned. It is now the highest-priority native ASR path because it gives LocalVoiceFlow an in-process CoreML backend and Vowen positions it as the macOS streaming/preview choice.

Batch Parakeet checks now passed or implemented:

- It transcribes a 2-5 second WAV from the command line on this Mac.
- Cold startup time was measured and is dominated by first CoreML compile.
- Warm transcription time was measured as sub-second for the synthetic smoke case.
- Model load stays resident through `FluidAudioBatchASREngine`.
- It can be selected/downloaded through the app model manager.
- It transcribes the app's in-memory ring-buffer samples without temp WAV.

Parakeet checks still needed:

- It must be tested on more real user voice samples.
- Packaging path is clear: CoreML/MLX/native helper, not a fragile Python-only runtime.
- License and model redistribution path are acceptable.
- Failure mode is clean and whisper.cpp fallback remains available.
- Streaming partials and EOU must be implemented through FluidAudio's streaming APIs rather than the batch engine.

Parakeet benchmark acceptance:

```text
warm 5s utterance <= whisper.cpp small.en-q5_1 latency
quality >= whisper.cpp small.en-q5_1 on user voice samples
startup acceptable for launch-time model warmup
no cloud dependency
no raw audio saved by default
```

## UX Decision Tree

```text
User presses shortcut
├── if permissions missing
│   ├── do not fake recording
│   ├── show exact missing permission
│   └── provide open settings action
├── if model missing
│   ├── show selected model missing
│   ├── offer download/select path
│   └── keep app usable after download
├── if ready
│   ├── start recording immediately
│   ├── show compact overlay
│   ├── show target app
│   ├── show listening/speech/processing states
│   └── leave final text visible briefly
└── if insertion fails
    ├── keep transcript on clipboard
    ├── show "copied, paste manually" state
    └── save history unless privacy disables it
```

## Cleanup Decision Tree

```text
Raw dictation
└── ASR text + artifact filtering only.

Fast cleanup
├── remove filler words
├── remove silence/music/noise artifacts
├── apply punctuation commands
├── apply line/paragraph/list commands
├── apply dictionary replacements
└── conservative capitalization/spacing.

Polished local cleanup
├── same fast cleanup
├── local small LLM only after final transcript
├── preserve wording by default
├── app-specific prompts later
└── no cloud provider.
```

## Benchmark Tree

```text
Benchmark corpus
├── synthetic `say` smoke tests
├── user voice short commands
├── user voice casual English
├── accent/slang samples
├── silence and noise samples
├── first-word / last-word samples
├── Notes/Chrome/Codex target-app paste tests
└── longer 30-60s notes samples

Metrics
├── WER / CER
├── artifact false positives
├── repeated phrase rate
├── first partial latency
├── speech-end-to-final latency
├── hotkey-to-recording latency
├── memory use
├── cold startup
└── warm steady-state throughput
```

## VoiceInk Repo Findings

Repository reviewed:

- https://github.com/Beingpax/VoiceInk.git
- Local research clone used: `/tmp/VoiceInk`
- License: GPLv3. Treat as architecture research only. Do not copy source code into LocalVoiceFlow unless the whole project license strategy is intentionally made GPL-compatible.

### What VoiceInk Proves

- A serious macOS dictation app should be an Xcode app, not only a SwiftPM command runner.
- Embedded whisper.cpp through `whisper.xcframework` is a real production path. It avoids per-request process spawn and avoids a local HTTP server in the core ASR path.
- Parakeet is not theoretical. VoiceInk integrates it through `FluidAudio` with `parakeet-tdt-0.6b-v2` and `parakeet-tdt-0.6b-v3`.
- Real partial transcription requires a streaming session object, an audio chunk callback, and a committed-vs-hypothesis text model.
- VoiceInk's FluidAudio streaming path repeatedly transcribes buffered audio and uses a word agreement engine before committing text.
- The recorder should expose the same 16 kHz mono PCM stream both to disk/file transcription and to realtime streaming.
- Model prewarming matters. VoiceInk prewarms local models after launch/wake using a bundled short WAV.
- Permission UX needs polling and recovery actions, not just one-time checks.
- Clipboard paste needs session ownership metadata if restore is enabled, otherwise the app can restore over a user-changed clipboard.
- Shortcut handling should support toggle, push-to-talk, hybrid behavior, modifier-only shortcuts, interruption detection, secondary shortcuts, and mouse triggers.
- App/context modes are a major UX advantage: active app/URL can select model, cleanup, enhancement, output behavior, and prompt style.

### VoiceInk Architecture Map

```text
VoiceInk
├── app shell
│   ├── Xcode project
│   ├── menu bar app
│   ├── Sparkle updates
│   ├── onboarding
│   └── SwiftData history
├── recording
│   ├── AUHAL CoreAudio recorder
│   ├── selected device support
│   ├── pre-allocated audio buffers
│   ├── 16 kHz mono Int16 output
│   ├── streaming audio callback
│   ├── audio meter
│   ├── optional media pause/mute
│   └── WAV files saved for history/retry
├── ASR
│   ├── embedded whisper.cpp XCFramework
│   ├── FluidAudio Parakeet
│   ├── native Apple speech path
│   ├── cloud providers
│   ├── model manager
│   └── prewarm service
├── streaming
│   ├── TranscriptionSession protocol
│   ├── StreamingTranscriptionService
│   ├── AsyncStream audio chunk source
│   ├── provider abstraction
│   ├── FluidAudioStreamingProvider
│   ├── committed segments
│   ├── partial hypothesis
│   ├── final commit with timeout
│   └── batch fallback on streaming failure
├── post-processing
│   ├── hallucination bracket/tag filtering
│   ├── filler word removal
│   ├── paragraph formatter
│   ├── word replacements
│   ├── punctuation cleanup modes
│   └── optional AI enhancement
├── insertion
│   ├── clipboard set
│   ├── CGEvent Cmd+V
│   ├── AppleScript paste fallback
│   ├── clipboard restore delay
│   ├── session marker before restore
│   └── optional auto-send key
├── shortcuts
│   ├── CGEvent tap
│   ├── modifier-only shortcuts
│   ├── toggle / push-to-talk / hybrid
│   ├── primary and secondary recording shortcuts
│   ├── shortcut interruption handling
│   ├── middle-click toggle
│   └── utility shortcuts for history/dictionary/retry
└── modes
    ├── active app triggers
    ├── browser URL triggers
    ├── per-mode model choice
    ├── per-mode prompt/cleanup
    └── per-mode output behavior
```

### Ideas To Reimplement Independently

- Embedded whisper.cpp backend using an XCFramework or Swift/C bridge.
- FluidAudio Parakeet benchmark and possible production backend.
- Streaming session lifecycle:
  - `prepare()` returns an audio callback immediately.
  - audio chunks buffer while the backend connects.
  - partial text updates the overlay.
  - final stop commits buffered audio and falls back to batch if streaming fails.
- Word agreement for partials:
  - maintain confirmed text separately from hypothesis text.
  - only paste confirmed/final text.
  - deduplicate final text by overlap/timing.
- CoreAudio/AUHAL recorder only if AVAudioEngine start latency or device control becomes a blocker.
- Model prewarm after app launch, wake, and model switch.
- Permission polling after opening System Settings.
- Clipboard restore with a paste-session marker, only restoring when the pasteboard still contains the transcript generated by the app.
- Mode system later:
  - raw model/cleanup for coding tools.
  - polished cleanup for notes/email.
  - app/URL triggers, but only after the core dictation loop is stable.

### Ideas To Avoid Or Delay

- Do not save recording WAVs by default. VoiceInk keeps audio files for history/retry; LocalVoiceFlow's privacy default is no audio saved.
- Do not add cloud transcription providers.
- Do not add license/account/update infrastructure now.
- Do not add AI assistant or command mode before dictation quality is excellent.
- Do not copy GPLv3 source code.
- Do not make mode/profile complexity visible before first-run dictation works cleanly.

### How VoiceInk Changes Our ASR Plan

Old priority:

```text
whisper.cpp server fallback
-> benchmark Parakeet later
-> maybe embedded backend
```

Updated priority:

```text
1. Keep whisper.cpp server as the working fallback.
2. Add a benchmark lane for FluidAudio Parakeet V3.
3. Add an embedded whisper.cpp backend plan, because VoiceInk shows this is practical in Swift/Xcode.
4. Choose the production default by benchmark:
   ├── Parakeet if it wins streaming latency and quality on user voice
   ├── embedded whisper.cpp if Whisper quality wins and latency is acceptable
   └── current whisper-server only as fallback/dev path
5. Implement real partials through the chosen resident backend, not through CLI chunks.
```

## Immediate Build Priorities

1. Build a real benchmark harness around the user's own voice samples.
2. Compare whisper.cpp `base.en-q5_1`, `small.en-q5_1`, and `large-v3-turbo-q5_0`.
3. Add FluidAudio Parakeet V3 to the benchmark lane and measure cold load, warm final latency, first partial latency, memory, and accuracy.
4. Decide production ASR backend from benchmarks:
   - FluidAudio Parakeet for streaming if it wins.
   - embedded whisper.cpp if Whisper quality wins.
   - current whisper-server remains fallback.
5. Add pre-roll/post-roll audio handling to reduce first/last word cutoffs.
6. Add stronger junk detection for silence hallucinations and repeated phrases.
7. Implement real committed-vs-hypothesis partial text in the overlay.
8. Improve the overlay with target app, copied/pasted status, and last transcript.
9. Add model readiness and recovery UI.
10. Add app-specific cleanup defaults only after the raw loop is stable.

## Non-Negotiables

- No cloud APIs in the default or required path.
- No login.
- No subscription.
- No audio saved by default.
- No mock ASR in the real app path.
- No fake success messages.
- Keep whisper.cpp command/server backend as fallback.
- Keep the main thread responsive.
- If paste fails, copy must still work.
- Every model/backend claim needs a local benchmark before becoming default.
