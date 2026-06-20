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
        #expect(settings.dictation.holdControlThresholdMilliseconds == 80)
        #expect(settings.dictation.clipboardRestoreDelayMilliseconds == 600)
        #expect(settings.dictation.pasteTargetBehavior == .focusedAtStart)
        #expect(settings.dictation.pasteStrategy == .balanced)
        #expect(settings.dictation.floatingOverlayStyle == .voiceBars)
        #expect(settings.dictation.floatingOverlayPalette == .scrivora)
        #expect(settings.dictation.floatingOverlayPlacement == .bottom)
        #expect(settings.updates.automaticChecksEnabled == true)
        #expect(settings.updates.manifestURLString == "")
        #expect(settings.updates.includePrerelease == false)
    }

    @Test func settingsStoreRoundTripsJSON() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(directory: directory)
        var settings = AppSettings.default
        settings.dictation.autoPaste = false
        settings.dictation.floatingOverlayStyle = .signalHelix
        settings.dictation.floatingOverlayPalette = .graphite
        settings.privacy.privacyMode = true

        try store.save(settings)
        let loaded = try store.load()

        #expect(loaded.dictation.autoPaste == false)
        #expect(loaded.dictation.floatingOverlayStyle == .signalHelix)
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
        #expect(settings.dictation.holdControlThresholdMilliseconds == 80)
        #expect(settings.dictation.restoreClipboardAfterPaste == true)
        #expect(settings.dictation.clipboardRestoreDelayMilliseconds == 600)
        #expect(settings.dictation.pasteTargetBehavior == PasteTargetBehavior.focusedAtStart)
        #expect(settings.dictation.pasteStrategy == PasteStrategy.balanced)
        #expect(settings.dictation.floatingOverlayStyle == FloatingOverlayStyle.voiceBars)
        #expect(settings.dictation.floatingOverlayPalette == FloatingOverlayPalette.scrivora)
        #expect(settings.dictation.floatingOverlayPlacement == FloatingOverlayPlacement.bottom)
        #expect(settings.models.selectedASRMode == ASRUserMode.balanced)
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
        #expect(settings.updates.automaticChecksEnabled == true)
        #expect(settings.updates.manifestURLString == "")
    }

    @Test func settingsDecodeOldCopyOnlyInsertionAsCopyOnlyStrategy() throws {
        let oldSettingsJSON = """
        {
          "dictation": {
            "autoPaste": false,
            "copyToClipboard": true,
            "restoreClipboardAfterPaste": false,
            "clipboardRestoreDelayMilliseconds": 900
          }
        }
        """

        let settings = try JSONDecoder().decode(
            AppSettings.self,
            from: Data(oldSettingsJSON.utf8)
        )

        #expect(settings.dictation.autoPaste == false)
        #expect(settings.dictation.pasteTargetBehavior == .focusedAtStart)
        #expect(settings.dictation.pasteStrategy == .copyOnly)
        #expect(settings.dictation.clipboardRestoreDelayMilliseconds == 900)
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

    @Test func downloadableWhisperModelsHavePinnedDigests() {
        let whisperModels = ModelCatalog.default.models.filter { $0.backend == .whisperCpp && $0.downloadURL != nil }

        #expect(!whisperModels.isEmpty)
        #expect(whisperModels.allSatisfy { model in
            guard let digest = model.downloadSHA256 else { return false }
            return digest.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil
        })
    }

    @Test func catalogIncludesHighQualityWhisperOptions() {
        let catalog = ModelCatalog.default

        #expect(catalog.model(id: "whispercpp-large-v3-turbo-q5")?.downloadSHA256 == "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2")
        #expect(catalog.model(id: "whispercpp-medium-q5")?.estimatedSizeMB == 514)
        #expect(catalog.model(id: "whispercpp-large-v3-q5")?.mode == .highestQuality)
        #expect(catalog.recommendedModel(for: .accurate)?.id == "whispercpp-large-v3-turbo-q5")
    }

    @Test func catalogBestAvailableFallbackPrefersDefaultParakeetWhenTinyIsMissing() {
        let catalog = ModelCatalog.default

        let fallback = catalog.bestAvailableASRModel(
            preferredMode: .instant,
            availableIDs: Set(["fluidaudio-parakeet-v3", "fluidaudio-parakeet-v2", "whispercpp-base-en-q5"])
        )

        #expect(fallback?.id == "fluidaudio-parakeet-v3")
    }

    @Test func catalogBestAvailableFallbackReturnsNilWhenNothingIsDownloaded() {
        let catalog = ModelCatalog.default

        #expect(catalog.bestAvailableASRModel(availableIDs: []) == nil)
    }

    @Test func modelIntegrityRejectsTamperedBytes() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("model.bin")
        try Data("trusted model bytes".utf8).write(to: url)
        let expected = try ModelIntegrity.sha256Hex(of: url)

        try ModelIntegrity.verifySHA256(of: url, expected: expected)

        try Data("tampered model bytes".utf8).write(to: url)
        #expect(throws: LocalVoiceFlowError.self) {
            try ModelIntegrity.verifySHA256(of: url, expected: expected)
        }
    }

    @Test func updateManifestDecodesRequiredDistributionFields() throws {
        let data = Data("""
        {
          "appID": "me.scrivora.app",
          "version": "0.4.1",
          "build": "2",
          "channel": "beta",
          "minimumSystemVersion": "14.0",
          "downloadURL": "https://updates.example.com/Scrivora-0.4.1.zip",
          "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          "archiveSizeBytes": 123456,
          "releaseNotesURL": "https://updates.example.com/Scrivora-0.4.1.html",
          "notes": ["Paste reliability fixes", "Update installer"],
          "critical": true,
          "requiresGatekeeperAssessment": false
        }
        """.utf8)

        let manifest = try JSONDecoder().decode(AppUpdateManifest.self, from: data)

        #expect(manifest.appID == "me.scrivora.app")
        #expect(manifest.version == "0.4.1")
        #expect(manifest.channel == "beta")
        #expect(manifest.downloadURL.absoluteString == "https://updates.example.com/Scrivora-0.4.1.zip")
        #expect(manifest.sha256.count == 64)
        #expect(manifest.notes.count == 2)
        #expect(manifest.critical == true)
    }

    @Test func updateVersionComparatorHandlesSemanticVersions() {
        #expect(AppUpdateVersionComparator.isVersion("0.4.1", newerThan: "0.4.0"))
        #expect(AppUpdateVersionComparator.isVersion("0.5.0", newerThan: "0.4.9"))
        #expect(AppUpdateVersionComparator.isVersion("1.0.0", newerThan: "0.9.9"))
        #expect(!AppUpdateVersionComparator.isVersion("0.4.0", newerThan: "0.4.0"))
        #expect(!AppUpdateVersionComparator.isVersion("0.3.9", newerThan: "0.4.0"))
        #expect(!AppUpdateVersionComparator.isVersion("0.4.0-beta", newerThan: "0.4.0"))
    }

    @Test func pasteStrategiesMapToExpectedRestoreDelays() {
        #expect(PasteStrategy.instant.restoreDelayMilliseconds(customDelay: 750) == nil)
        #expect(PasteStrategy.fast.restoreDelayMilliseconds(customDelay: 750) == 300)
        #expect(PasteStrategy.balanced.restoreDelayMilliseconds(customDelay: 750) == 600)
        #expect(PasteStrategy.safe.restoreDelayMilliseconds(customDelay: 750) == 1_000)
        #expect(PasteStrategy.custom.restoreDelayMilliseconds(customDelay: 750) == 750)
        #expect(PasteStrategy.copyOnly.restoreDelayMilliseconds(customDelay: 750) == nil)
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

    @Test func performanceLoggerRecordsPastePipelineMetrics() async {
        let logger = PerformanceLogger()
        let paste = PastePipelineMetrics(
            method: "clipboardPaste",
            targetBehavior: "focusedAtStart",
            targetAppName: "Notes",
            targetBundleIdentifier: "com.apple.Notes",
            focusChanged: false,
            fallbackUsed: false,
            clipboardSnapshotDuration: 0.01,
            clipboardSetDuration: 0.02,
            targetFocusCheckDuration: 0.03,
            commandVPostDuration: 0.04,
            visibleInsertLatency: 0.09,
            clipboardRestoreDelay: 0.60,
            clipboardRestoreDuration: 0.05,
            totalPastePipelineDuration: 0.74,
            backgroundClipboardRestoreLatency: 0.65
        )

        await logger.setPastePipelineMetrics(paste)
        await logger.setUserVisibleStopToInsertLatency(0.42)
        let metrics = await logger.finishCurrent()

        #expect(metrics.pasteMethod == "clipboardPaste")
        #expect(metrics.pasteTargetBehavior == "focusedAtStart")
        #expect(metrics.pasteTargetAppName == "Notes")
        #expect(metrics.pasteTargetBundleIdentifier == "com.apple.Notes")
        #expect(metrics.pasteFocusChanged == false)
        #expect(metrics.pasteFallbackUsed == false)
        #expect(metrics.clipboardSnapshotDuration == 0.01)
        #expect(metrics.clipboardSetDuration == 0.02)
        #expect(metrics.targetFocusCheckDuration == 0.03)
        #expect(metrics.commandVPostDuration == 0.04)
        #expect(metrics.visibleInsertLatency == 0.09)
        #expect(metrics.clipboardRestoreDelay == 0.60)
        #expect(metrics.clipboardRestoreDuration == 0.05)
        #expect(metrics.totalPastePipelineDuration == 0.74)
        #expect(metrics.backgroundClipboardRestoreLatency == 0.65)
        #expect(metrics.userVisibleStopToInsertLatency == 0.42)
    }

    @Test func tempAudioFileManagerCreatesAndRemovesManagedWAVFiles() throws {
        let directory = temporaryDirectory()
        let manager = TempAudioFileManager(directory: directory, prefix: "ScrivoraTempAudioTest")
        let url = try manager.createTemporaryWAV(samples: [0, 0.1, -0.1], sampleRate: 16_000)

        #expect(url.lastPathComponent.hasPrefix("ScrivoraTempAudioTest-"))
        #expect(url.pathExtension == "wav")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(manager.isManagedTemporaryFile(url))

        manager.removeTemporaryFile(url)

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func tempAudioFileManagerRemovesOnlyManagedStaleFiles() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let manager = TempAudioFileManager(directory: directory, prefix: "ScrivoraTempAudioTest")
        let managedWAV = directory.appendingPathComponent("ScrivoraTempAudioTest-\(UUID().uuidString).wav")
        let managedTXT = directory.appendingPathComponent("ScrivoraTempAudioTest-\(UUID().uuidString).txt")
        let unrelated = directory.appendingPathComponent("unrelated.wav")
        try Data("wav".utf8).write(to: managedWAV)
        try Data("txt".utf8).write(to: managedTXT)
        try Data("keep".utf8).write(to: unrelated)

        let removed = manager.removeStaleTemporaryFiles()

        #expect(Set(removed.map(\.lastPathComponent)) == Set([managedWAV.lastPathComponent, managedTXT.lastPathComponent]))
        #expect(!FileManager.default.fileExists(atPath: managedWAV.path))
        #expect(!FileManager.default.fileExists(atPath: managedTXT.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
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
                latencyMetrics: LatencyMetrics(
                    speechEndToFinalASR: 0.12,
                    pasteTargetAppName: "Notes",
                    pasteTargetBundleIdentifier: "com.apple.Notes"
                )
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
            metrics: LatencyMetrics(
                speechEndToFinalASR: 0.12,
                pasteTargetAppName: "Codex",
                pasteTargetBundleIdentifier: "com.openai.codex",
                pasteFailureReason: "Codex focus changed in com.openai.codex while reading /Users/rebel/private/meeting-notes.wav"
            ),
            pasteMethod: "clipboardPaste",
            error: "Failed to paste into Codex com.openai.codex with model /Users/rebel/Models/private-model.bin"
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
        #expect(history.first?.latencyMetrics.pasteTargetAppName == nil)
        #expect(history.first?.latencyMetrics.pasteTargetBundleIdentifier == nil)

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
        #expect(!logData.contains("com.apple.Notes"))
        #expect(!logData.contains("/Users/rebel"))
        #expect(!logData.contains("meeting-notes.wav"))
        #expect(!logData.contains("private-model.bin"))
        #expect(logData.contains("[redacted-path]"))
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
        #expect(v3?.downloadURL == nil)
        #expect(v2?.backend == .fluidAudio)
        #expect(v2?.engineIdentifier == "parakeet-tdt-0.6b-v2")
        #expect(v2?.downloadURL == nil)
    }

    @Test func defaultASRModelUsesParakeetV3BalancedBackend() {
        let settings = AppSettings.default
        let model = ModelCatalog.default.model(id: settings.models.selectedASRModelID)

        #expect(model?.id == "fluidaudio-parakeet-v3")
        #expect(model?.backend == .fluidAudio)
        #expect(model?.mode == .balanced)
        #expect(model?.downloadURL == nil)
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
