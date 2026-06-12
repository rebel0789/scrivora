# Scrivora Battery And Resource Benchmarks

Date: 2026-06-12

## Current Observations

Observed manually during prior testing:

- Idle CPU reached 0% after fixing overlay/activity behavior.
- Dictation with FluidAudio Parakeet is fast enough for local MVP use.
- Peak CPU during active transcription can be noticeably higher, which is expected for local ASR.

The current V0.3 work did not add a new Instruments trace. Treat these as local observations, not formal production benchmarks.

## Latest Functional Verification

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
Scripts/audit_sensitive_files.sh
```

Latest results:

- 49 tests passed.
- Build passed.
- Package passed.
- Sensitive-file audit found no Scrivora temp audio leftovers.

## Metrics Already Captured In App

Debug view shows:

- Hotkey to recording start.
- Recording start to speech detected.
- First partial latency.
- Speech end to final ASR.
- ASR to cleanup.
- Cleanup to paste.
- Paste method.
- Model load time.
- Model warmup time.

## Gaps

Not yet measured formally:

- RAM over a 30-minute idle run.
- RAM during repeated 30-second dictations.
- Energy impact in Instruments.
- CPU comparison against Vowen/Wispr/VoiceInk on the same input.
- Clipboard substep timing.
- Partial transcription cadence and dropped partial count.

## Next Benchmark Plan

1. Add a script that samples `ps` every second while Scrivora is idle.
2. Add a repeat-dictation benchmark using recorded local WAV prompts.
3. Capture:
   - CPU percent.
   - Resident memory.
   - Energy impact from Activity Monitor or Instruments.
   - ASR latency.
   - Paste latency.
4. Compare three engines:
   - FluidAudio Parakeet V2.
   - FluidAudio Parakeet V3.
   - whisper.cpp server fallback.
5. Document results by model, duration, and Mac hardware.

## Production Target

Initial local MVP target:

- Idle CPU: near 0%.
- Idle RAM: stable after model warmup.
- No unbounded growth across 100 short dictations.
- No leftover temporary audio files.
- No main-thread ASR work.
