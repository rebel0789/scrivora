# Scrivora Research

Research date: 2026-06-11

V0.2 update: the public product name is Scrivora. The repo path and Swift modules still use `LocalVoiceFlow` internally. Scrivora now defaults to FluidAudio Parakeet V2 for Instant mode, keeps whisper.cpp server/CLI as fallback paths, and implements pseudo-streaming Parakeet partials. True FluidAudio streaming/EOU remains the next ASR research target.

LocalVoiceFlow should start with a local Whisper-family ASR path because it is the most mature option for an offline macOS dictation product. The best first production backend is WhisperKit, with whisper.cpp kept as the fallback and portability backend. That is a deliberate adjustment from a pure whisper.cpp-first plan: whisper.cpp is excellent and mature, but WhisperKit now gives a Swift package, Apple-first Core ML deployment, model selection, microphone streaming CLI examples, and a lower-friction route to a native macOS app.

Update after reviewing VoiceInk on 2026-06-12: VoiceInk proves two production paths are practical in a native Swift macOS app: embedded whisper.cpp through `whisper.xcframework`, and Parakeet through FluidAudio. This moved Parakeet from "future benchmark candidate" to an implemented batch backend in LocalVoiceFlow. The current `whisper-server` backend remains useful as a working fallback, but it should not be the final low-latency architecture.

## Current ASR Options

| Option | Fit | Notes |
| --- | --- | --- |
| WhisperKit / Argmax OSS | Best native macOS MVP backend | Swift Package, macOS 14+, Xcode 16+, Core ML-oriented Whisper inference. Argmax recommends `tiny` for fastest debugging and `large-v3-v20240930_626MB` / turbo variants for high accuracy. The CLI supports file transcription and microphone streaming. MIT project license. |
| whisper.cpp | Best portable fallback and embedded production candidate | Mature C/C++ implementation, MIT, Apple Silicon first-class support through ARM NEON, Accelerate, Metal, and Core ML; supports macOS Intel and Arm, quantization, VAD, C API, and CPU-only fallback. VoiceInk embeds it as an XCFramework, which confirms this is a practical Swift/Xcode app path. |
| Faster Whisper / CTranslate2 | Useful for Python/server tooling, not first macOS app backend | Fast and memory-efficient, but packaging Python/CTranslate2 into a polished native macOS app is heavier. Apple acceleration is less straightforward than WhisperKit or whisper.cpp. |
| Distil-Whisper | Good future model family | Distil models report near-large-v3 quality with much better speed and smaller size, especially English. Needs careful runtime packaging and model availability per backend. |
| NVIDIA Parakeet TDT 0.6B v2/v3 via FluidAudio | Implemented batch backend; streaming candidate next | LocalVoiceFlow now links FluidAudio and supports Parakeet V2/V3 final transcription from in-memory samples. VoiceInk integrates Parakeet with streaming support and word-agreement partial stabilization, which remains the next benchmark target. |
| sherpa-onnx | Best future streaming alternative | Supports local streaming and non-streaming ASR, VAD, many platforms including macOS/iOS, and many language bindings. Good for a future lower-latency streaming backend after the first Whisper path ships. |
| Moonshine Voice / Moonshine v2 | Watch closely | Designed for low-latency streaming edge ASR with partials. It is newer and needs license/package/runtime verification before product commitment. |
| Vosk | Reliable fallback, lower accuracy ceiling | Offline, Apache-2.0 ecosystem, many languages, low resource use. Accuracy and modern dictation quality are behind Whisper-family options. |

## Recommended ASR Backend

1. **Working fallback now: whisper.cpp server or CLI.**
   - Keep this path because it already proves local transcription with Homebrew `whisper-cpp`.
   - It should remain the fallback and developer bootstrap path.
   - It should not be the final production low-latency path because it still uses a helper process and temporary WAV files.

2. **Production candidates to benchmark next:**
   - FluidAudio Parakeet V3 streaming/EOU for partials and Apple Silicon speed.
   - Embedded whisper.cpp through an XCFramework or Swift/C bridge for mature Whisper quality without process spawn.
   - WhisperKit large-v3-turbo if the full Xcode/Core ML path is available and benchmarks well.

3. **Backend interface stays stable.**
   - Keep `ASREngine` independent from FluidAudio, WhisperKit, and whisper.cpp details.
   - Add a streaming/session layer for partials instead of forcing partial transcription into a final-only `transcribeFinal` shape.

## First ASR Model Modes

| User Mode | First model choice | Runtime | Why |
| --- | --- | --- | --- |
| Instant | Whisper `tiny.en` or WhisperKit `tiny` | WhisperKit or whisper.cpp | Fastest debug and short chat/search dictation. |
| Balanced | Whisper `base.en` or `small.en` quantized | WhisperKit or whisper.cpp | Default for English-first dictation on most Macs. |
| Accurate | Parakeet V3 or Whisper `small` quantized | FluidAudio or whisper.cpp | Parakeet is now the preferred Apple Silicon local accuracy path; whisper.cpp remains fallback. |
| Highest Quality | Parakeet V2 English or Whisper large-v3-turbo / Argmax compressed turbo | FluidAudio or WhisperKit | V2 can be better for English recall; WhisperKit turbo remains a future comparison. |
| Experimental / Streaming | Parakeet EOU/streaming, sherpa-onnx Zipformer, Moonshine | Future adapters | Streaming partials still need a real session API and stabilization layer. |

## Local LLM Options

The LLM should be optional and final-pass only. Do not run it on every partial transcript.

| Option | Fit | License / packaging notes |
| --- | --- | --- |
| Qwen3 0.6B / 1.7B Instruct | Best first cleanup candidate | Apache-2.0 open-weight models, small enough for local cleanup, supports llama.cpp and MLX workflows. |
| Gemma 3 1B IT | Good quality, gated model access | Requires accepting Google's Gemma terms on Hugging Face. Good candidate if distribution flow can handle license acceptance. |
| Phi-4-mini-instruct | Higher quality, larger | Microsoft describes it as intended for latency/compute-constrained use, but 3.8B is heavier than needed for default transcript cleanup. |

## Recommended LLM Backend

**Start with llama.cpp for optional local LLM cleanup.** It has the broadest GGUF model support, Apple Silicon acceleration through Metal/Accelerate, quantization, and simple local deployment. MLX Swift is promising and Apple-native, but it is Apple-Silicon-only and should be a V1/V2 backend after the ASR flow is stable.

## Packaging Risks

- Full Xcode is required for a polished app bundle, microphone permission strings, signing, and notarization. The current machine only exposes Command Line Tools.
- WhisperKit currently targets macOS 14+ and Xcode 16+.
- Model files are large and should not be bundled in git.
- Hugging Face downloads require network and sometimes Git LFS; the app must make this explicit.
- Accessibility insertion varies by app. Clipboard paste with restoration must remain the reliable fallback.
- WhisperKit automatic model downloads must be disabled or surfaced through the model manager to preserve privacy expectations.
- Direct whisper.cpp C API integration requires a small Swift/C/C++ bridge and packaging a signed dynamic/static library.

## Unknowns To Benchmark

- First partial latency for WhisperKit `tiny`, `base.en`, `small.en`, and turbo models on the target Mac.
- End-to-final latency for 5s, 15s, and 30s utterances.
- Memory pressure when ASR and an optional Qwen/Gemma cleanup model are both loaded.
- Accuracy tradeoff between WhisperKit turbo compressed, whisper.cpp `small.en`, `medium`, and large-v3-turbo quantized models.
- Whether FluidAudio Parakeet V3 beats whisper.cpp `small.en-q5_1` and `large-v3-turbo-q5_0` on a larger set of the user's voice samples.
- Whether Parakeet cold startup is acceptable after launch/wake/model-switch prewarming in the packaged app.
- Whether embedded whisper.cpp can remove temp WAV and local HTTP overhead while preserving accuracy.
- Whether Moonshine or sherpa-onnx beats WhisperKit/Parakeet on first-token latency for dictation-quality English.
- How each target app handles paste, direct AX insertion, secure fields, and clipboard restoration timing.

## Final MVP Recommendation

Build the MVP as a SwiftUI menu bar app with:

- Warm ASR model lifecycle through `ASREngine`.
- AVAudioEngine capture into a 16 kHz mono in-memory buffer.
- Energy-based VAD and silence endpointing.
- Rolling chunk scheduler and stable final transcript builder.
- Fast deterministic cleanup.
- Accessibility-aware clipboard paste fallback with clipboard restoration.
- Local JSON storage for settings, history, model metadata, and performance logs.
- A benchmark-selected production ASR backend:
  - FluidAudio Parakeet batch is implemented now for final text.
  - FluidAudio Parakeet streaming/EOU should be tested next for partial text.
  - embedded whisper.cpp remains the mature Whisper fallback if Whisper quality wins.
  - WhisperKit remains a candidate if it proves better under Xcode/Core ML benchmarking.
- Keep the current whisper.cpp server/CLI backend as fallback and local setup bootstrap.

Sources:

- https://github.com/Beingpax/VoiceInk
- https://github.com/FluidInference/FluidAudio
- https://github.com/ggml-org/whisper.cpp
- https://github.com/openai/whisper
- https://huggingface.co/openai/whisper-large-v3-turbo
- https://github.com/argmaxinc/argmax-oss-swift
- https://github.com/k2-fsa/sherpa-onnx
- https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2
- https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- https://github.com/SYSTRAN/faster-whisper
- https://github.com/huggingface/distil-whisper
- https://github.com/ggml-org/llama.cpp
- https://github.com/ml-explore/mlx-swift
- https://qwenlm.github.io/blog/qwen3/
- https://github.com/QwenLM/Qwen3
- https://huggingface.co/microsoft/Phi-4-mini-instruct
- https://github.com/alphacep/vosk-api
- https://github.com/moonshine-ai/moonshine
