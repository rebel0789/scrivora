import Foundation
import Testing
@testable import LocalVoiceFlowCore

struct StorageAndModelTests {
    @Test func defaultSettingsArePrivacyRespecting() {
        let settings = AppSettings.default

        #expect(settings.privacy.saveAudio == false)
        #expect(settings.privacy.privacyMode == true)
        #expect(settings.privacy.saveTranscriptHistory == false)
        #expect(settings.privacy.saveLearningMemory == false)
        #expect(settings.privacy.savePerformanceLogs == true)
        #expect(settings.privacy.includeTargetAppInLogs == false)
        #expect(settings.privacy.includeTargetBundleIdentifierInLogs == false)
        #expect(settings.privacy.firstRunPrivacyChoiceCompleted == false)
        #expect(settings.privacy.selectedPrivacyProfile == .maximumPrivacy)
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
        #expect(settings.privacy.saveLearningMemory == true)
        #expect(settings.privacy.savePerformanceLogs == true)
        #expect(settings.privacy.includeTargetAppInLogs == false)
        #expect(settings.privacy.includeTargetBundleIdentifierInLogs == false)
        #expect(settings.privacy.firstRunPrivacyChoiceCompleted == false)
    }

    @Test func privacyProfilesApplyExpectedLocalStoragePolicies() {
        let maximum = PrivacySettings.settings(for: .maximumPrivacy)
        #expect(maximum.privacyMode == true)
        #expect(maximum.saveTranscriptHistory == false)
        #expect(maximum.saveLearningMemory == false)
        #expect(maximum.savePerformanceLogs == true)
        #expect(maximum.includeTargetAppInLogs == false)
        #expect(maximum.includeTargetBundleIdentifierInLogs == false)
        #expect(maximum.saveAudio == false)
        #expect(maximum.firstRunPrivacyChoiceCompleted == true)

        let balanced = PrivacySettings.settings(for: .balancedLocalMemory)
        #expect(balanced.privacyMode == false)
        #expect(balanced.saveTranscriptHistory == true)
        #expect(balanced.saveLearningMemory == true)
        #expect(balanced.savePerformanceLogs == true)
        #expect(balanced.includeTargetAppInLogs == false)
        #expect(balanced.includeTargetBundleIdentifierInLogs == false)

        let debug = PrivacySettings.settings(for: .debugMode)
        #expect(debug.privacyMode == false)
        #expect(debug.saveTranscriptHistory == true)
        #expect(debug.saveLearningMemory == true)
        #expect(debug.savePerformanceLogs == true)
        #expect(debug.includeTargetAppInLogs == true)
        #expect(debug.includeTargetBundleIdentifierInLogs == true)
        #expect(debug.saveAudio == false)
    }

    @Test func offlineModeBlocksRemoteDownloadsButAllowsLocalUse() {
        var privacy = PrivacySettings()
        privacy.offlineMode = true

        #expect(NetworkAccessPolicy.canDownloadRemoteModel(privacy: privacy) == false)
        #expect(NetworkAccessPolicy.canUseLocalModel(privacy: privacy) == true)
        #expect(NetworkAccessPolicy.canUseLocalhostService(privacy: privacy) == true)
    }

    @Test func storageMigrationStatusRecognizesLegacyRoot() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let legacyRoot = appSupport.appendingPathComponent("LocalVoiceFlow", isDirectory: true)

        let status = DataStorageMigrationService().status(currentRootDirectory: legacyRoot)

        #expect(status.usingLegacyRoot == true)
        #expect(status.legacyRootPath.hasSuffix("LocalVoiceFlow"))
        #expect(status.scrivoraRootPath.hasSuffix("Scrivora"))
    }

    @Test func performanceLoggerRecordsFirstPartialBreakdownOnce() async {
        let logger = PerformanceLogger()

        await logger.setFirstPartialRequestLatency(0.72)
        await logger.setFirstPartialRequestLatency(0.90)
        await logger.setFirstPartialASRDuration(0.18)
        await logger.setFirstPartialASRDuration(0.30)
        await logger.setFirstPartialLatency(0.94)
        await logger.setFirstPartialLatency(1.20)
        let metrics = await logger.finishCurrent()

        #expect(metrics.firstPartialRequestLatency == 0.72)
        #expect(metrics.firstPartialASRDuration == 0.18)
        #expect(metrics.firstPartialLatency == 0.94)
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

        try store.append(first, respecting: PrivacySettings.settings(for: .balancedLocalMemory))
        try store.append(second, respecting: PrivacySettings.settings(for: .balancedLocalMemory))
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

    @Test func redactedDebugExportRemovesPersonalTextTargetMetadataAndLocalPaths() throws {
        let root = temporaryDirectory()
        let exportRoot = temporaryDirectory()
        let fileStore = LocalFileStore(rootDirectory: root)
        try fileStore.prepareDirectories()

        let privacy = PrivacySettings.settings(for: .debugMode)
        let historyStore = HistoryStore(directory: fileStore.historyDirectory)
        try historyStore.append(
            HistoryRecord(
                finalTranscript: "private sentence about my project",
                targetAppName: "Notes",
                asrModelID: "fluidaudio-parakeet-v3",
                cleanupMode: .fast,
                outputProfile: "general",
                latencyMetrics: LatencyMetrics(speechEndToFinalASR: 0.12)
            ),
            respecting: privacy
        )

        let correctionStore = CorrectionStore(directory: fileStore.learningDirectory)
        try correctionStore.append(CorrectionRecord(
            originalTranscript: "uh private phrase",
            correctedTranscript: "private phrase",
            targetAppName: "TextEdit",
            asrModelID: "fluidaudio-parakeet-v3",
            outputProfile: "general",
            learnedEntries: [UserDictionaryEntry(spokenForm: "uh private phrase", writtenForm: "private phrase")]
        ))

        let performanceStore = PerformanceLogStore(directory: fileStore.logsDirectory)
        try performanceStore.append(PerformanceLogRecord(
            triggerMode: "holdControl",
            asrBackend: "fluidAudio",
            modelID: "fluidaudio-parakeet-v3",
            outputProfile: "general",
            targetAppName: "Codex",
            targetBundleIdentifier: "com.openai.codex",
            streamingMode: "pseudoStreaming",
            durationRecorded: 1.5,
            metrics: LatencyMetrics(speechEndToFinalASR: 0.12),
            pasteMethod: "clipboardPaste",
            error: nil
        ))

        var settings = AppSettings.default
        settings.privacy = privacy
        settings.models.customASRModelPath = root.appendingPathComponent("model.bin").path

        let result = try PrivacyExportService(
            fileStore: fileStore,
            fluidAudioDirectory: root.appendingPathComponent("FluidAudio", isDirectory: true)
        ).export(
            options: .redactedDebugPackage,
            to: exportRoot,
            settings: settings
        )

        #expect(result.manifest.redactedTranscriptText == true)
        #expect(result.manifest.redactedTargetMetadata == true)
        #expect(result.manifest.redactedLocalPaths == true)
        #expect(result.manifest.files.contains("history.json"))
        #expect(result.manifest.files.contains("learning-corrections.json"))
        #expect(result.manifest.files.contains("performance-logs-redacted.jsonl"))

        let history = try decode([HistoryRecord].self, from: result.directory.appendingPathComponent("history.json"))
        #expect(history.first?.finalTranscript == "[redacted]")
        #expect(history.first?.targetAppName == nil)

        let corrections = try decode([CorrectionRecord].self, from: result.directory.appendingPathComponent("learning-corrections.json"))
        #expect(corrections.first?.originalTranscript == "[redacted]")
        #expect(corrections.first?.correctedTranscript == "[redacted]")
        #expect(corrections.first?.targetAppName == nil)
        #expect(corrections.first?.learnedEntries.isEmpty == true)

        let settingsExport = try decode(AppSettings.self, from: result.directory.appendingPathComponent("settings.json"))
        #expect(settingsExport.models.customASRModelPath == nil)

        let storage = try decode([StorageSummaryEntry].self, from: result.directory.appendingPathComponent("storage-summary.json"))
        #expect(storage.allSatisfy { $0.path == "[redacted]" })

        let logData = try String(contentsOf: result.directory.appendingPathComponent("performance-logs-redacted.jsonl"), encoding: .utf8)
        #expect(!logData.contains("Codex"))
        #expect(!logData.contains("com.openai.codex"))
    }

    @Test func individualPrivacyExportsWriteOnlyRequestedFiles() throws {
        let root = temporaryDirectory()
        let exportRoot = temporaryDirectory()
        let fileStore = LocalFileStore(rootDirectory: root)
        try fileStore.prepareDirectories()

        try HistoryStore(directory: fileStore.historyDirectory).append(
            HistoryRecord(
                finalTranscript: "local history item",
                targetAppName: "Notes",
                asrModelID: "fluidaudio-parakeet-v2",
                cleanupMode: .fast,
                latencyMetrics: LatencyMetrics()
            ),
            respecting: PrivacySettings.settings(for: .balancedLocalMemory)
        )
        try CorrectionStore(directory: fileStore.learningDirectory).append(CorrectionRecord(
            originalTranscript: "before",
            correctedTranscript: "after",
            targetAppName: "Notes",
            asrModelID: "fluidaudio-parakeet-v2",
            outputProfile: "general",
            learnedEntries: []
        ))
        try PerformanceLogStore(directory: fileStore.logsDirectory).append(PerformanceLogRecord(
            triggerMode: "holdControl",
            asrBackend: "fluidAudio",
            modelID: "fluidaudio-parakeet-v2",
            outputProfile: "general",
            targetAppName: nil,
            targetBundleIdentifier: nil,
            streamingMode: "pseudoStreaming",
            durationRecorded: 1.0,
            metrics: LatencyMetrics(speechEndToFinalASR: 0.1),
            pasteMethod: "clipboardPaste",
            error: nil
        ))

        let cases: [(PrivacyExportOptions, Set<String>)] = [
            (.settingsOnly, ["settings.json"]),
            (.historyOnly, ["history.json"]),
            (.learningOnly, ["learning-corrections.json"]),
            (.performanceLogsOnly, ["performance-logs.jsonl"])
        ]

        for (options, expectedFiles) in cases {
            let destination = exportRoot.appendingPathComponent(options.name, isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let result = try PrivacyExportService(fileStore: fileStore).export(
                options: options,
                to: destination,
                settings: .default
            )
            #expect(Set(result.manifest.files) == expectedFiles)
            #expect(FileManager.default.fileExists(atPath: result.directory.appendingPathComponent("manifest.json").path))
        }
    }

    @Test func historyExportWritesEmptyArrayWhenHistoryIsDisabledOrAbsent() throws {
        let root = temporaryDirectory()
        let exportRoot = temporaryDirectory()
        let fileStore = LocalFileStore(rootDirectory: root)
        try fileStore.prepareDirectories()

        let result = try PrivacyExportService(fileStore: fileStore).export(
            options: .historyOnly,
            to: exportRoot,
            settings: .default
        )
        let history = try decode([HistoryRecord].self, from: result.directory.appendingPathComponent("history.json"))

        #expect(history.isEmpty)
        #expect(result.manifest.files == ["history.json"])
    }

    @Test func fullLocalExportIncludesUserOwnedTextAndPaths() throws {
        let root = temporaryDirectory()
        let exportRoot = temporaryDirectory()
        let fileStore = LocalFileStore(rootDirectory: root)
        try fileStore.prepareDirectories()

        try HistoryStore(directory: fileStore.historyDirectory).append(
            HistoryRecord(
                finalTranscript: "keep this exact local transcript",
                targetAppName: "Notes",
                asrModelID: "fluidaudio-parakeet-v2",
                cleanupMode: .fast,
                outputProfile: "general",
                latencyMetrics: LatencyMetrics()
            ),
            respecting: PrivacySettings.settings(for: .balancedLocalMemory)
        )

        var settings = AppSettings.default
        settings.privacy = PrivacySettings.settings(for: .balancedLocalMemory)
        settings.models.customASRModelPath = root.appendingPathComponent("model.bin").path

        let result = try PrivacyExportService(fileStore: fileStore).export(
            options: .fullLocalPackage,
            to: exportRoot,
            settings: settings
        )

        #expect(result.manifest.redactedTranscriptText == false)
        #expect(result.manifest.redactedTargetMetadata == false)
        #expect(result.manifest.redactedLocalPaths == false)

        let history = try decode([HistoryRecord].self, from: result.directory.appendingPathComponent("history.json"))
        #expect(history.first?.finalTranscript == "keep this exact local transcript")
        #expect(history.first?.targetAppName == "Notes")

        let settingsExport = try decode(AppSettings.self, from: result.directory.appendingPathComponent("settings.json"))
        #expect(settingsExport.models.customASRModelPath == root.appendingPathComponent("model.bin").path)
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

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
