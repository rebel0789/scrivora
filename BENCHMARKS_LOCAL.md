# Scrivora Local Benchmarks

Date: 2026-06-12

These benchmarks use local-only audio. No audio was uploaded. The quick synthetic sample was generated with macOS `say`; it is useful for smoke testing latency and parser behavior, but it is not a substitute for real user voice samples.

## Current Recommendation

- Instant mode: Parakeet V2 English plus Fast deterministic cleanup.
- Balanced mode: Parakeet V3.
- Compatible fallback: persistent `whisper-server`.
- Emergency fallback: `whisper-cli`.

V0.3 did not change the ASR recommendation. It added privacy defaults, export, Offline Mode download blocking, and signing cleanup around the existing local ASR paths.

Parakeet V2 is still the preferred default because the user reported it is much more accurate on their real voice than the earlier whisper.cpp path. The synthetic sample below slightly favors whisper/V3 for the word `Scrivora`, so a real voice benchmark set is still required before production claims.

## Synthetic Smoke Benchmark

Sample text:

```text
Scrivora turns my voice into polished text anywhere on my Mac
```

| Engine | Path | Model loaded? | Temp audio? | Avg latency | WER | Note |
| --- | --- | --- | --- | ---: | ---: | --- |
| whisper.cpp base.en-q5_1 | external `whisper-cli` | no, process per run | yes | 0.216 s | 0.000 | Correct synthetic transcript. |
| FluidAudio Parakeet V2 | in-process app path, CLI for benchmark | yes in app | no in app | 0.295 s | 0.091 | Rendered `Scrivora` as `Scravora` on synthetic voice; user voice quality was better than whisper. |
| FluidAudio Parakeet V3 | in-process app path, CLI for benchmark | yes in app | no in app | 0.234 s | 0.000 | Correct synthetic transcript. |

Earlier direct Parakeet smoke tests on a simple local sample:

- Parakeet V3: about 0.16 s processing, 24.46x RTFx, confidence 0.933.
- Parakeet V2: about 0.12 s processing, 33.88x RTFx, confidence 0.961.

## What To Benchmark Next

Record 10-20 short local-only real voice samples covering:

- casual sentence
- accent/slang
- punctuation commands
- bullet list commands
- noisy room
- short one-word/phrase dictation
- long sentence with correction-like repetition

Run:

```bash
Scripts/record_benchmark_samples.sh
Scripts/benchmark_asr.py \
  --manifest BenchmarkSamples/manifest.csv \
  --include-fluidaudio \
  --fluidaudio-cli Vendor/FluidAudio/.build/release/fluidaudiocli \
  --fluidaudio-model-version v2 \
  --whisper-model ggml-base.en-q5_1.bin
```

Repeat with `--fluidaudio-model-version v3`.

Do not commit personal voice recordings.
