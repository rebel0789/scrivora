# Scrivora Open Source Strategy

Date: 2026-06-12

## Position

Scrivora should remain local-first:

- No cloud ASR dependency.
- No login.
- No subscription gate.
- No audio saved by default.
- No mock ASR in the real app path.

## What Can Be Open Sourced Safely

Good candidates:

- Core audio ring buffer, VAD, chunk scheduling, and endpointing.
- Text cleanup and app-aware output profiles.
- Local storage model.
- Privacy export format.
- Packaging and local install scripts.
- Benchmark harness.
- Documentation and audit process.

## What Needs Care

Review before publishing:

- Any bundled third-party model weights or model URLs.
- FluidAudio dependency and model licensing notes.
- whisper.cpp integration details.
- Local signing scripts.
- Screenshots or logs that may include user data.

Never publish:

- `.build/dev-signing`.
- Private keys.
- p12 files.
- Keychains.
- Local history, corrections, logs, or exports.
- Model caches if licensing does not allow redistribution.

## Repository Hygiene

Before open sourcing:

```bash
Scripts/audit_sensitive_files.sh
git status --short
git ls-files
```

Also verify:

- `.gitignore` blocks signing material.
- No local app support files are copied into the repo.
- No personal transcript examples are in docs or tests.
- Benchmark samples are either synthetic or explicitly safe.

## Product Direction

Open source can help with:

- Local ASR backend experimentation.
- VAD/endpointing improvements.
- macOS paste reliability.
- Benchmarks across hardware.
- Privacy review.

Keep proprietary or delayed until stable:

- Brand/design assets.
- Growth/positioning copy.
- Any future paid packaging or update channel.

## Next Open Source Steps

1. Add license file.
2. Add third-party notices.
3. Add model license summary.
4. Add contribution guide.
5. Add security policy.
6. Add reproducible setup script for Parakeet and whisper.cpp.
7. Run a clean clone build.
