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
    }

    @Test func settingsStoreRoundTripsJSON() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(directory: directory)
        var settings = AppSettings.default
        settings.dictation.autoPaste = false
        settings.privacy.privacyMode = true

        try store.save(settings)
        let loaded = try store.load()

        #expect(loaded.dictation.autoPaste == false)
        #expect(loaded.privacy.privacyMode == true)
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

    @Test func defaultASRModelUsesImplementedLocalWhisperBackend() {
        let settings = AppSettings.default
        let model = ModelCatalog.default.model(id: settings.models.selectedASRModelID)

        #expect(model?.backend == .whisperCpp)
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
