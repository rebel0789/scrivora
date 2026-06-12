# FluidAudio Parakeet MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real local Parakeet ASR path that keeps the model loaded, transcribes in-memory microphone samples, and preserves whisper.cpp as the fallback.

**Architecture:** Keep `LocalVoiceFlowCore` as the stable protocol/types package and add FluidAudio only to the `LocalVoiceFlowApp` executable target. The app will select a `FluidAudioBatchASREngine` for Parakeet models, load models from FluidAudio's cache without implicit startup downloads, and use explicit download actions from the settings UI.

**Tech Stack:** Swift 6.1, SwiftPM, SwiftUI, FluidAudio `v0.15.2`, CoreML, existing LocalVoiceFlow `ASREngine` protocol.

---

### Task 1: Catalog And Settings Contract

**Files:**
- Modify: `Sources/LocalVoiceFlowCore/ASRTypes.swift`
- Modify: `Sources/LocalVoiceFlowCore/ModelCatalog.swift`
- Modify: `Tests/LocalVoiceFlowCoreTests/StorageAndModelTests.swift`

- [ ] **Step 1: Write failing catalog tests**

```swift
@Test func catalogIncludesFluidAudioParakeetModels() {
    let catalog = ModelCatalog.default
    let v3 = catalog.model(id: "fluidaudio-parakeet-v3")
    let v2 = catalog.model(id: "fluidaudio-parakeet-v2")

    #expect(v3?.backend == .fluidAudio)
    #expect(v3?.engineIdentifier == "parakeet-tdt-0.6b-v3")
    #expect(v3?.downloadURL?.absoluteString.contains("FluidInference/parakeet-tdt-0.6b-v3-coreml") == true)
    #expect(v2?.backend == .fluidAudio)
    #expect(v2?.engineIdentifier == "parakeet-tdt-0.6b-v2")
}
```

- [ ] **Step 2: Verify the test fails**

Run: `swift test --filter StorageAndModelTests/catalogIncludesFluidAudioParakeetModels`

Expected: fail because `ASRBackend.fluidAudio` and Parakeet catalog entries do not exist yet.

- [ ] **Step 3: Add the backend and catalog entries**

Add `case fluidAudio` to `ASRBackend`. Add Parakeet v3 and v2 `ASRModelInfo` entries with FluidAudio backend, explicit Hugging Face model URLs, local folder names, estimated size/memory labels, and permissive-license labels from the upstream model metadata.

- [ ] **Step 4: Verify catalog tests pass**

Run: `swift test --filter StorageAndModelTests`

Expected: all storage/model tests pass.

### Task 2: FluidAudio App Dependency And Engine

**Files:**
- Modify: `Package.swift`
- Create: `Sources/LocalVoiceFlowApp/FluidAudioBatchASREngine.swift`
- Modify: `Sources/LocalVoiceFlowApp/AppState.swift`

- [ ] **Step 1: Add FluidAudio dependency**

Add `.package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.2")` and attach `.product(name: "FluidAudio", package: "FluidAudio")` only to the `LocalVoiceFlowApp` executable target.

- [ ] **Step 2: Implement cache-only batch engine**

Create an app-only actor conforming to `ASREngine`. It maps `parakeet-tdt-0.6b-v3` to `AsrModelVersion.v3` and `parakeet-tdt-0.6b-v2` to `.v2`, checks `AsrModels.modelsExist(at:version:)`, loads with `AsrModels.load(from:version:)`, keeps one `AsrManager` loaded, transcribes `AudioBuffer.samples` directly, appends a short silence pad for finalization, and returns `LocalVoiceFlowCore.ASRResult`.

- [ ] **Step 3: Wire app selection**

Update `makeASREngine(for:)`, `prepareSelectedASRModelIfPossible()`, and `normalizeSettingsForImplementedBackend()` so `.fluidAudio` is implemented and no longer reset to whisper.cpp.

- [ ] **Step 4: Verify build catches API drift**

Run: `swift build --product LocalVoiceFlowApp`

Expected: build succeeds and no app target uses FluidAudio APIs from `main` that are absent in tag `0.15.2`.

### Task 3: Explicit Model Download And UI Status

**Files:**
- Create: `Sources/LocalVoiceFlowApp/FluidAudioModelSupport.swift`
- Modify: `Sources/LocalVoiceFlowApp/AppState.swift`
- Modify: `Sources/LocalVoiceFlowApp/Views.swift`

- [ ] **Step 1: Implement model support helper**

Add `FluidAudioModelSupport` with `version(for:)`, `cacheDirectory(for:)`, `isDownloaded(_:)`, `download(_:)`, and `delete(_:)`. `isDownloaded` must use FluidAudio's cache directory and `modelsExist`; `download` is only called from the user's settings action.

- [ ] **Step 2: Wire download and delete**

Branch `downloadModel(_:)`, `deleteModel(_:)`, and `isModelDownloaded(_:)` by backend. Whisper continues to use `ModelStorage`; FluidAudio uses `FluidAudioModelSupport`.

- [ ] **Step 3: Clarify settings copy**

Update the model manager note so users understand Parakeet models live under `~/Library/Application Support/FluidAudio/Models` and first use may compile CoreML models.

- [ ] **Step 4: Verify model state**

Run: `swift test` and `swift build --product LocalVoiceFlowApp`.

Expected: no regressions, FluidAudio models compile into the app target, and the settings path copy builds.

### Task 4: Benchmark And Documentation

**Files:**
- Modify: `Scripts/benchmark_asr.py`
- Modify: `README.md`
- Modify: `AUDIT.md`
- Modify: `RESEARCH.md`

- [ ] **Step 1: Add FluidAudio benchmark runner**

Add `--include-fluidaudio`, `--fluidaudio-cli`, `--fluidaudio-model-version`, and `--fluidaudio-model-dir`. Parse only the CLI transcript from stdout and keep stderr logs out of WER scoring.

- [ ] **Step 2: Document install/test flow**

Update README with: install app, download/select Parakeet v3 in settings, grant microphone/accessibility permissions, test in Notes/TextEdit/Chrome, and fallback to whisper.cpp if FluidAudio is not desired.

- [ ] **Step 3: Update audit status**

Move Parakeet batch ASR from missing/future work to implemented-but-batch. Keep streaming partials, FluidAudio VAD, and production polish listed as remaining work.

- [ ] **Step 4: Verify packaging**

Run:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
```

Expected: tests pass, app product builds, and `.build/LocalVoiceFlowApp.app` is produced.
