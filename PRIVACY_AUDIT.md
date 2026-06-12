# Scrivora Privacy Audit

Date: 2026-06-12

## Current Privacy Defaults

Fresh installs default to Maximum Privacy:

- `privacyMode`: on.
- `saveTranscriptHistory`: off.
- `saveLearningMemory`: off.
- `savePerformanceLogs`: on.
- `includeTargetAppInLogs`: off.
- `includeTargetBundleIdentifierInLogs`: off.
- `saveAudio`: off.
- `analyticsEnabled`: off.

Existing settings are migrated conservatively. Older users who already had transcript history enabled keep that stored value until they choose a first-run privacy profile, and missing learning-memory settings inherit the old transcript-history value.

## Local Data Written

Scrivora may write these local files under:

```text
~/Library/Application Support/LocalVoiceFlow
```

- `Settings/settings.json`: app preferences and local model paths.
- `History/history.json`: saved dictations only when transcript history is enabled and Privacy Mode is off.
- `Learning/corrections.json`: saved corrections only when learning memory is enabled and Privacy Mode is off.
- `Logs/dictation-performance.jsonl`: latency metrics when performance logging is enabled.
- `Models/*`: whisper.cpp fallback model files.

FluidAudio Parakeet models are cached by FluidAudio under:

```text
~/Library/Application Support/FluidAudio/Models
```

Model files are not exported by Scrivora privacy export.

V0.3 keeps the legacy `LocalVoiceFlow` app support folder to avoid breaking existing data and permissions during the public rename. The Privacy screen now shows migration status: current storage name, whether the legacy folder exists, and whether a future `Scrivora` folder exists. V0.3 does not auto-move or delete user data.

## Audio Handling

The live app captures microphone audio into memory. Raw audio is not saved by default.

Current backend behavior:

- FluidAudio Parakeet runs in process on in-memory audio buffers.
- whisper-server receives a temporary WAV for the local HTTP request and deletes it after use.
- whisper-cli receives a temporary WAV and deletes it after transcription.

The audit script now checks for Scrivora-shaped temporary audio leftovers:

```bash
Scripts/audit_sensitive_files.sh
```

Latest audit result: no Scrivora audio/temp candidates outside model caches.

## Logging

Performance logs are local JSONL. Privacy Mode forces target app name and target bundle identifier to `nil` even if debug toggles are on.

Debug Mode can include target app metadata by user choice. It still does not save raw audio.

## Privacy Export

Settings -> Privacy supports:

- Settings.
- History.
- Learning.
- Performance logs.
- Full local package.
- Redacted debug package.

The redacted debug package removes:

- Transcript text.
- Correction text.
- Learned phrase entries.
- Target app names.
- Target bundle identifiers.
- Local filesystem paths.

The redacted debug package includes:

- `settings.json`
- `history.json`
- `learning-corrections.json`
- `performance-logs-redacted.jsonl`
- `storage-summary.json`
- `debug-summary.json`
- `manifest.json`

Signing material and model files are excluded.

## Current Findings

Fully working:

- Fresh default is privacy-first.
- First-run privacy choice exists.
- Privacy profile changes are saved.
- Offline Mode blocks in-app remote model downloads.
- Redacted debug export removes personal text, target metadata, and local paths.
- Full local export keeps user-owned local text and paths.
- Dev signing material is no longer stored in normal app support.
- Sensitive-file audit script does not print file contents.

Partially working:

- Performance logs are useful but still minimal. They do not yet record detailed clipboard substeps.
- Privacy export covers app data stores, but it is not encrypted.

Missing:

- No signed/notarized production build.
- No automatic periodic privacy audit.
- No user-facing one-click purge for FluidAudio model cache. Model deletion is still model-specific.

Real-world blockers:

- Production distribution needs Developer ID signing and notarization.
- Some existing users may have old local history/learning data; they must clear it from Settings -> Privacy if they want a clean Maximum Privacy state.

Verification:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
Scripts/audit_sensitive_files.sh
```

Latest verification:

- `swift test`: 49 tests passed.
- `swift build --product LocalVoiceFlowApp`: passed.
- `Scripts/package_app_bundle.sh`: passed, signed with `LocalVoiceFlow Development`.
