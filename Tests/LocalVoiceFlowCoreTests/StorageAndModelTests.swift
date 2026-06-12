import Foundation
import Testing
@testable import LocalVoiceFlowCore

struct StorageAndModelTests {
    @Test func defaultSettingsArePrivacyRespecting() {
        let settings = AppSettings.default

        #expect(settings.privacy.saveAudio == false)
        #expect(settings.privacy.saveTranscriptHistory == true)
        #expect(settings.privacy.analyticsEnabled == false)
        #expect(settings.dictation.restoreClipboardAfterPaste == true)
        #expect(settings.dictation.shortcut.isControlTap == true)
        #expect(settings.dictation.shortcut.displayName == "Control Tap")
        #expect(settings.dictation.triggerMode == .holdControl)
        #expect(settings.dictation.clipboardRestoreDelayMilliseconds == 600)
        #expect(settings.dictation.floatingOverlayStyle == .liquidFlow)
        #expect(settings.dictation.floatingOverlayPalette == .aurora)
    }

    @Test func settingsStoreRoundTripsJSON() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(directory: directory)
        var settings = AppSettings.default
        settings.dictation.autoPaste = false
        settings.dictation.floatingOverlayStyle = .spectrumBloom
        settings.dictation.floatingOverlayPalette = .graphite
        settings.privacy.privacyMode = true

        try store.save(settings)
        let loaded = try store.load()

        #expect(loaded.dictation.autoPaste == false)
        #expect(loaded.dictation.floatingOverlayStyle == .spectrumBloom)
        #expect(loaded.dictation.floatingOverlayPalette == .graphite)
        #expect(loaded.privacy.privacyMode == true)
    }

    @Test func settingsDecodeDefaultsMissingNewFields() throws {
        let oldSettingsJSON = """
        {
          "dictation": {
            "shortcut": { "key": "space", "modifiers": ["control", "option"] },
            "mode": "toggle",
            "autoStopOnSilence": true,
            "silenceDurationMilliseconds": 900,
            "startStopSound": true,
            "showFloatingOverlay": true,
            "autoPaste": true,
            "copyToClipboard": true,
            "longDictationMode": false
          },
          "models": {
            "selectedASRModelID": "fluidaudio-parakeet-v2",
            "useMetalAcceleration": true,
            "preferQuantizedModels": true
          },
          "postProcessing": {
            "cleanupMode": "fast",
            "preset": "cleanPunctuation",
            "customPrompt": ""
          },
          "privacy": {
            "privacyMode": false,
            "saveTranscriptHistory": true,
            "saveAudio": false,
            "offlineMode": false,
            "analyticsEnabled": false
          }
        }
        """

        let settings = try JSONDecoder().decode(
            AppSettings.self,
            from: Data(oldSettingsJSON.utf8)
        )

        #expect(settings.dictation.triggerMode == TriggerMode.holdControl)
        #expect(settings.dictation.restoreClipboardAfterPaste == true)
        #expect(settings.dictation.clipboardRestoreDelayMilliseconds == 600)
        #expect(settings.dictation.floatingOverlayStyle == FloatingOverlayStyle.liquidFlow)
        #expect(settings.dictation.floatingOverlayPalette == FloatingOverlayPalette.aurora)
        #expect(settings.models.selectedASRMode == ASRUserMode.instant)
        #expect(settings.models.preferPersistentWhisperServer == true)
        #expect(settings.postProcessing.outputProfile == DictationOutputProfile.automatic)
        #expect(settings.postProcessing.customReplacements.contains { $0.replacement == "Scrivora" })
        #expect(settings.postProcessing.customReplacements.contains { $0.phrase == "u a" && $0.replacement == "UI" })
        #expect(settings.postProcessing.customReplacements.contains { $0.phrase == "text edit" && $0.replacement == "TextEdit" })
    }

    @Test func historyStorePersistsNewestDictationFirstWhenPrivacyAllows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HistoryStore(directory: directory)
        let first = HistoryRecord(
            finalTranscript: "first dictation",
            targetAppName: "TextEdit",
            asrModelID: "whispercpp-base-en-q5",
            cleanupMode: .fast,
            latencyMetrics: LatencyMetrics(speechEndToFinalASR: 0.8)
        )
        let second = HistoryRecord(
            finalTranscript: "second dictation",
            targetAppName: "Notes",
            asrModelID: "whispercpp-base-en-q5",
            cleanupMode: .fast,
            latencyMetrics: LatencyMetrics(speechEndToFinalASR: 0.6)
        )

        try store.append(first, respecting: PrivacySettings())
        try store.append(second, respecting: PrivacySettings())
        let records = try store.load()

        #expect(records.map(\.finalTranscript) == ["second dictation", "first dictation"])
    }

    @Test func historyStoreDoesNotPersistInPrivacyMode() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HistoryStore(directory: directory)
        var privacy = PrivacySettings()
        privacy.privacyMode = true
        let record = HistoryRecord(
            finalTranscript: "private dictation",
            targetAppName: nil,
            asrModelID: "whispercpp-base-en-q5",
            cleanupMode: .raw,
            latencyMetrics: LatencyMetrics()
        )

        try store.append(record, respecting: privacy)

        #expect(try store.load().isEmpty)
    }

    @Test func performanceLogStoreWritesCompactJsonLines() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = PerformanceLogStore(directory: directory)
        let record = PerformanceLogRecord(
            triggerMode: "holdControl",
            asrBackend: "fluidAudio",
            modelID: "fluidaudio-parakeet-v3",
            outputProfile: "agent",
            targetAppName: "Codex",
            targetBundleIdentifier: "com.openai.codex",
            streamingMode: "pseudoStreaming",
            durationRecorded: 4.2,
            metrics: LatencyMetrics(speechEndToFinalASR: 0.12),
            pasteMethod: "clipboardPaste",
            error: nil
        )

        try store.append(record)
        try store.append(record)

        let logURL = directory.appendingPathComponent("dictation-performance.jsonl")
        let lines = try String(contentsOf: logURL, encoding: .utf8).split(separator: "\n")

        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.first == "{" && $0.last == "}" })
    }

    @Test func performanceLogStoreClearRemovesLocalLogFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = PerformanceLogStore(directory: directory)
        let record = PerformanceLogRecord(
            triggerMode: "holdControl",
            asrBackend: "fluidAudio",
            modelID: "fluidaudio-parakeet-v3",
            outputProfile: "general",
            targetAppName: nil,
            targetBundleIdentifier: nil,
            streamingMode: "pseudoStreaming",
            durationRecorded: 1.4,
            metrics: LatencyMetrics(speechEndToFinalASR: 0.10),
            pasteMethod: "clipboardPaste",
            error: nil
        )

        try store.append(record)
        let logURL = directory.appendingPathComponent("dictation-performance.jsonl")
        #expect(FileManager.default.fileExists(atPath: logURL.path))

        try store.clear()

        #expect(!FileManager.default.fileExists(atPath: logURL.path))
    }

    @Test func modelCatalogMapsUserModesToLocalModels() {
        let catalog = ModelCatalog.default

        #expect(catalog.recommendedModel(for: .instant)?.mode == .instant)
        #expect(catalog.recommendedModel(for: .balanced)?.mode == .balanced)
        #expect(catalog.models.contains { $0.license.lowercased().contains("mit") })
    }

    @Test func catalogIncludesFluidAudioParakeetModels() {
        let catalog = ModelCatalog.default
        let v3 = catalog.model(id: "fluidaudio-parakeet-v3")
        let v2 = catalog.model(id: "fluidaudio-parakeet-v2")

        #expect(v3?.backend == .fluidAudio)
        #expect(v3?.engineIdentifier == "parakeet-tdt-0.6b-v3")
        #expect(v3?.downloadURL?.absoluteString.contains("FluidInference/parakeet-tdt-0.6b-v3-coreml") == true)
        #expect(v2?.backend == .fluidAudio)
        #expect(v2?.engineIdentifier == "parakeet-tdt-0.6b-v2")
        #expect(v2?.downloadURL?.absoluteString.contains("FluidInference/parakeet-tdt-0.6b-v2-coreml") == true)
    }

    @Test func defaultASRModelUsesParakeetV2InstantBackend() {
        let settings = AppSettings.default
        let model = ModelCatalog.default.model(id: settings.models.selectedASRModelID)

        #expect(model?.id == "fluidaudio-parakeet-v2")
        #expect(model?.backend == .fluidAudio)
        #expect(model?.mode == .instant)
        #expect(model?.downloadURL != nil)
        #expect(settings.models.preferPersistentWhisperServer == true)
    }

    @Test func modelSettingsCanStoreExplicitWhisperBinaryAndModelPath() {
        var settings = AppSettings.default

        settings.models.whisperExecutablePath = "/opt/homebrew/bin/whisper-cli"
        settings.models.customASRModelPath = "/Users/test/ggml-base.en.bin"

        #expect(settings.models.whisperExecutablePath == "/opt/homebrew/bin/whisper-cli")
        #expect(settings.models.customASRModelPath == "/Users/test/ggml-base.en.bin")
    }
}
