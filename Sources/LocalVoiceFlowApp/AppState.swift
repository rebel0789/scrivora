import AppKit
import Foundation
import LocalVoiceFlowCore

enum DictationRuntimeState: Equatable {
    case idle
    case listening
    case speechDetected
    case partialTranscription
    case processing
    case finished
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Idle"
        case .listening: "Listening"
        case .speechDetected: "Speech detected"
        case .partialTranscription: "Transcribing"
        case .processing: "Processing"
        case .finished: "Finished"
        case .failed: "Error"
        }
    }
}

struct StorageUsageItem: Identifiable, Equatable {
    let id: String
    var title: String
    var path: String
    var byteCount: Int64
    var detail: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var runtimeState: DictationRuntimeState = .idle
    @Published var partialTranscript: String = ""
    @Published var finalTranscript: String = ""
    @Published var lastError: String?
    @Published var history: [HistoryRecord] = []
    @Published var latestMetrics = LatencyMetrics()
    @Published var microphonePermission: PermissionState = .unknown
    @Published var accessibilityPermission: PermissionState = .unknown
    @Published var modelDownloadMessage: String?
    @Published var activeDictationProfile: ResolvedDictationProfile = .fallback
    @Published var correctionRecords: [CorrectionRecord] = []
    @Published var improvementStats = ImprovementStats()
    @Published var learningMessage: String?
    @Published var voiceLevel: Double = 0
    @Published var voiceBrightness: Double = 0
    @Published var voiceSpectrum: VoiceSpectrumBands = .silent
    @Published var storageUsageItems: [StorageUsageItem] = []
    @Published var storageStatusMessage: String?
    @Published var privacyExportMessage: String?
    @Published var storageMigrationStatus: DataStorageMigrationStatus?

    let fileStore: LocalFileStore
    let modelCatalog = ModelCatalog.default

    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let performanceLogStore: PerformanceLogStore
    private let correctionStore: CorrectionStore
    private let modelStorage: ModelStorage
    private let appProfileResolver = AppProfileResolver()
    private let correctionLearner = CorrectionLearner()
    private let audioCapture = AudioCaptureService()
    private let textInserter = TextInsertionService()
    private let permissions = PermissionsManager()
    private let performanceLogger = PerformanceLogger()
    private let overlayController = FloatingOverlayController()
    private var ringBuffer = AudioRingBuffer(capacity: 16_000 * 90)
    private var chunkScheduler = ChunkScheduler()
    private var vad = VoiceActivityDetector()
    private var silenceDetector = SilenceDetector(requiredSilentFrames: 24)
    private var hotkeyManager: HotkeyManager?
    private var dictationRequestedAt: Date?
    private var recordingStartedAt: Date?
    private var speechEndedAt: Date?
    private var firstSpeechDetectedAt: Date?
    private var firstPartialTranscriptAt: Date?
    private var cachedASREngine: (modelID: String, engine: any ASREngine)?
    private var targetApplication: NSRunningApplication?
    private var lastNonLocalVoiceFlowApplication: NSRunningApplication?
    private var partialTranscriptTask: Task<Void, Never>?
    private var lastPartialRequestedAt: Date?
    private var partialStabilizer = PartialTranscriptStabilizer(requiredRepeats: 2)
    private var partialSequenceNumber = 0

    init() {
        fileStore = LocalFileStore()
        settingsStore = SettingsStore(directory: fileStore.settingsDirectory)
        historyStore = HistoryStore(directory: fileStore.historyDirectory)
        performanceLogStore = PerformanceLogStore(directory: fileStore.logsDirectory)
        correctionStore = CorrectionStore(directory: fileStore.learningDirectory)
        modelStorage = ModelStorage(directory: fileStore.modelsDirectory)

        try? fileStore.prepareDirectories()
        settings = (try? settingsStore.load()) ?? .default
        normalizeSettingsForImplementedBackend()
        history = (try? historyStore.load()) ?? []
        correctionRecords = (try? correctionStore.load()) ?? []
        improvementStats = (try? correctionStore.stats()) ?? ImprovementStats()
        storageMigrationStatus = DataStorageMigrationService().status(currentRootDirectory: fileStore.rootDirectory)
        refreshStorageUsage()

        refreshPermissions()
        configureSilenceDetector()
        registerHotkey()
        observeApplicationActivation()
        observeTermination()
        Task { @MainActor [weak self] in
            self?.syncOverlay()
        }
        Task { await prepareSelectedASRModelIfPossible() }
    }

    var menuBarSystemImage: String {
        switch runtimeState {
        case .idle, .finished:
            "waveform"
        case .listening, .speechDetected:
            "mic.fill"
        case .partialTranscription:
            "waveform.badge.magnifyingglass"
        case .processing:
            "gearshape.2.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var selectedModel: ASRModelInfo? {
        modelCatalog.model(id: settings.models.selectedASRModelID)
    }

    var dataFolderPath: String {
        fileStore.rootDirectory.path
    }

    var totalLocalStorageSize: String {
        let total = storageUsageItems.reduce(Int64(0)) { $0 + $1.byteCount }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var needsFirstRunPrivacyChoice: Bool {
        !settings.privacy.firstRunPrivacyChoiceCompleted
    }

    func refreshPermissions() {
        microphonePermission = permissions.microphonePermissionState()
        accessibilityPermission = permissions.accessibilityPermissionState()
    }

    func requestMicrophonePermission() {
        Task {
            microphonePermission = await permissions.requestMicrophonePermission()
        }
    }

    func requestAccessibilityPermission() {
        accessibilityPermission = permissions.requestAccessibilityPermission()
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    func toggleDictation() {
        switch runtimeState {
        case .listening, .speechDetected, .partialTranscription:
            stopDictation()
        case .processing:
            break
        default:
            dictationRequestedAt = Date()
            startDictation()
        }
    }

    func startDictation() {
        refreshPermissions()
        guard microphonePermission == .granted else {
            fail("Microphone permission is required before dictation can start.")
            return
        }

        ringBuffer.clear()
        chunkScheduler.reset()
        silenceDetector.reset()
        voiceLevel = 0
        voiceBrightness = 0
        voiceSpectrum = .silent
        partialTranscript = ""
        finalTranscript = ""
        lastError = nil
        firstSpeechDetectedAt = nil
        firstPartialTranscriptAt = nil
        speechEndedAt = nil
        lastPartialRequestedAt = nil
        partialSequenceNumber = 0
        partialStabilizer.reset()
        dictationRequestedAt = dictationRequestedAt ?? Date()
        recordingStartedAt = Date()
        targetApplication = preferredTargetApplication()
        activeDictationProfile = resolvedProfile(for: targetApplication)

        do {
            try audioCapture.start { [weak self] samples in
                Task { @MainActor in
                    self?.handleCapturedSamples(samples)
                }
            }
            runtimeState = .listening
            if let dictationRequestedAt {
                let elapsed = Date().timeIntervalSince(dictationRequestedAt)
                Task { await performanceLogger.setHotkeyToRecordingStart(elapsed) }
            }
            syncOverlay()
        } catch {
            fail(error.localizedDescription)
        }
    }

    func stopDictation() {
        audioCapture.stop()
        voiceLevel = 0
        voiceBrightness = 0
        voiceSpectrum = .silent
        partialTranscriptTask?.cancel()
        partialTranscriptTask = nil
        guard runtimeState != .processing else { return }
        runtimeState = .processing
        syncOverlay()
        speechEndedAt = Date()

        let audio = AudioBuffer(samples: ringBuffer.snapshot(), sampleRate: 16_000)
        Task {
            await transcribeAndInsert(audio)
        }
    }

    func selectModel(_ model: ASRModelInfo) {
        settings.models.selectedASRModelID = model.id
        settings.models.selectedASRMode = model.mode
        invalidateASREngine()
        saveSettings()
        Task { await prepareSelectedASRModelIfPossible() }
    }

    func isModelDownloaded(_ model: ASRModelInfo) -> Bool {
        if model.backend == .fluidAudio {
            return FluidAudioModelSupport.isDownloaded(model)
        }
        if model.id == settings.models.selectedASRModelID,
           let path = settings.models.customASRModelPath,
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FileManager.default.fileExists(atPath: path)
        }
        return modelStorage.isDownloaded(model)
    }

    func setPreferPersistentWhisperServer(_ enabled: Bool) {
        settings.models.preferPersistentWhisperServer = enabled
        invalidateASREngine()
        saveSettings()
        Task { await prepareSelectedASRModelIfPossible() }
    }

    func setWhisperServerPath(_ path: String) {
        settings.models.whisperServerExecutablePath = normalizedOptionalPath(path)
        invalidateASREngine()
        saveSettings()
        Task { await prepareSelectedASRModelIfPossible() }
    }

    func setWhisperExecutablePath(_ path: String) {
        settings.models.whisperExecutablePath = normalizedOptionalPath(path)
        invalidateASREngine()
        saveSettings()
        Task { await prepareSelectedASRModelIfPossible() }
    }

    func setCustomASRModelPath(_ path: String) {
        settings.models.customASRModelPath = normalizedOptionalPath(path)
        invalidateASREngine()
        saveSettings()
        Task { await prepareSelectedASRModelIfPossible() }
    }

    func downloadModel(_ model: ASRModelInfo) {
        guard NetworkAccessPolicy.canDownloadRemoteModel(privacy: settings.privacy) else {
            modelDownloadMessage = "Offline Mode is on. Scrivora will only use local models and local services. Remote model downloads are disabled."
            return
        }

        guard model.downloadURL != nil else {
            modelDownloadMessage = "No direct download is configured for \(model.displayName)."
            return
        }

        modelDownloadMessage = "Downloading \(model.displayName)..."
        Task {
            do {
                switch model.backend {
                case .whisperCpp:
                    _ = try await ModelDownloader().download(model: model, to: modelStorage)
                case .fluidAudio:
                    _ = try await FluidAudioModelSupport.download(model)
                default:
                    throw LocalVoiceFlowError.modelUnavailable("Direct app download is enabled for whisper.cpp and FluidAudio Parakeet models.")
                }
                selectModel(model)
                modelDownloadMessage = "Downloaded \(model.displayName)."
            } catch {
                modelDownloadMessage = error.localizedDescription
            }
        }
    }

    func deleteModel(_ model: ASRModelInfo) {
        do {
            if model.backend == .fluidAudio {
                try FluidAudioModelSupport.delete(model)
            } else {
                try modelStorage.delete(model)
            }
            if settings.models.selectedASRModelID == model.id {
                invalidateASREngine()
            }
            modelDownloadMessage = "Deleted \(model.displayName)."
        } catch {
            modelDownloadMessage = error.localizedDescription
        }
    }

    func setPrivacyMode(_ enabled: Bool) {
        settings.privacy.privacyMode = enabled
        saveSettings()
    }

    func applyPrivacyChoice(_ profile: PrivacyProfile) {
        settings.privacy = PrivacySettings.settings(for: profile)
        saveSettings()
        refreshStorageUsage()
    }

    func clearHistory() {
        do {
            try historyStore.clear()
            history = []
            refreshStorageUsage()
        } catch {
            fail(error.localizedDescription)
        }
    }

    func learnCorrection(for record: HistoryRecord, correctedTranscript: String) {
        guard settings.privacy.saveLearningMemory, !settings.privacy.privacyMode else {
            learningMessage = "Learning memory is disabled by your privacy settings."
            return
        }

        let corrected = correctedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty else {
            learningMessage = "Correction is empty."
            return
        }
        guard corrected != record.finalTranscript else {
            learningMessage = "No correction to learn."
            return
        }

        let learning = correctionLearner.learn(
            original: record.finalTranscript,
            corrected: corrected
        )
        let correction = CorrectionRecord(
            originalTranscript: record.finalTranscript,
            correctedTranscript: corrected,
            targetAppName: record.targetAppName,
            asrModelID: record.asrModelID,
            outputProfile: record.outputProfile,
            learnedEntries: learning.entries
        )

        do {
            try correctionStore.append(correction)
            mergeLearnedEntries(learning.entries)
            saveSettings()
            correctionRecords = (try? correctionStore.load()) ?? []
            improvementStats = (try? correctionStore.stats()) ?? ImprovementStats()
            refreshStorageUsage()
            learningMessage = learning.entries.isEmpty
                ? "Saved correction. No safe automatic phrase rule was inferred."
                : "Learned \(learning.entries.count) phrase rule\(learning.entries.count == 1 ? "" : "s")."
        } catch {
            learningMessage = error.localizedDescription
        }
    }

    func clearCorrections() {
        do {
            try correctionStore.clear()
            correctionRecords = []
            improvementStats = ImprovementStats()
            learningMessage = "Correction memory cleared."
            refreshStorageUsage()
        } catch {
            learningMessage = error.localizedDescription
        }
    }

    func clearPerformanceLogs() {
        do {
            try performanceLogStore.clear()
            storageStatusMessage = "Performance logs cleared."
            refreshStorageUsage()
        } catch {
            storageStatusMessage = error.localizedDescription
        }
    }

    func clearLocalTextData() {
        do {
            try historyStore.clear()
            try correctionStore.clear()
            try performanceLogStore.clear()
            history = []
            correctionRecords = []
            improvementStats = ImprovementStats()
            storageStatusMessage = "History, learning, and performance logs cleared."
            refreshStorageUsage()
        } catch {
            storageStatusMessage = error.localizedDescription
        }
    }

    func exportPrivacyData(options: PrivacyExportOptions) {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            let result = try PrivacyExportService(
                fileStore: fileStore,
                fluidAudioDirectory: fluidAudioSupportDirectory()
            ).export(
                options: options,
                to: destination,
                settings: settings
            )
            privacyExportMessage = "Exported \(result.manifest.exportName) package to \(result.directory.path)."
            NSWorkspace.shared.activateFileViewerSelecting([result.directory])
        } catch {
            privacyExportMessage = error.localizedDescription
        }
    }

    func refreshStorageUsage() {
        storageMigrationStatus = DataStorageMigrationService().status(currentRootDirectory: fileStore.rootDirectory)
        let performanceLogURL = fileStore.logsDirectory.appendingPathComponent("dictation-performance.jsonl")
        let fluidAudioRoot = fluidAudioSupportDirectory()
        storageUsageItems = [
            StorageUsageItem(
                id: "history",
                title: "Transcript history",
                path: fileStore.historyDirectory.path,
                byteCount: byteCount(at: fileStore.historyDirectory),
                detail: "\(history.count) saved dictations"
            ),
            StorageUsageItem(
                id: "learning",
                title: "Learning memory",
                path: fileStore.learningDirectory.path,
                byteCount: byteCount(at: fileStore.learningDirectory),
                detail: "\(improvementStats.correctionCount) correction records"
            ),
            StorageUsageItem(
                id: "performance",
                title: "Performance logs",
                path: fileStore.logsDirectory.path,
                byteCount: byteCount(at: fileStore.logsDirectory),
                detail: "\(lineCount(at: performanceLogURL)) latency entries"
            ),
            StorageUsageItem(
                id: "settings",
                title: "Settings",
                path: fileStore.settingsDirectory.path,
                byteCount: byteCount(at: fileStore.settingsDirectory),
                detail: "preferences and local paths"
            ),
            StorageUsageItem(
                id: "whisper-models",
                title: "Whisper models",
                path: fileStore.modelsDirectory.path,
                byteCount: byteCount(at: fileStore.modelsDirectory),
                detail: "local fallback models"
            ),
            StorageUsageItem(
                id: "fluidaudio-models",
                title: "FluidAudio models",
                path: fluidAudioRoot.path,
                byteCount: byteCount(at: fluidAudioRoot),
                detail: "Parakeet model cache"
            )
        ]
    }

    func openDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileStore.rootDirectory])
    }

    func saveSettings() {
        do {
            try settingsStore.save(settings)
            configureSilenceDetector()
            registerHotkey()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func handleCapturedSamples(_ samples: [Float]) {
        ringBuffer.append(samples)
        updateVoiceLevel(samples)

        let isSpeech = vad.isSpeech(samples)
        if isSpeech {
            if firstSpeechDetectedAt == nil {
                let detectedAt = Date()
                firstSpeechDetectedAt = detectedAt
                if let recordingStartedAt {
                    let elapsed = detectedAt.timeIntervalSince(recordingStartedAt)
                    Task { await performanceLogger.setRecordingStartToSpeechDetected(elapsed) }
                }
            }
            runtimeState = .speechDetected
            if partialTranscript.isEmpty {
                partialTranscript = "Listening..."
            }
            syncOverlay()
            requestPartialTranscriptionIfNeeded()
        } else if runtimeState == .speechDetected || runtimeState == .partialTranscription {
            runtimeState = .listening
            syncOverlay()
        }

        _ = chunkScheduler.append(samples)

        if settings.dictation.autoStopOnSilence, silenceDetector.observe(isSpeech: isSpeech) {
            stopDictation()
        }
    }

    private func transcribeAndInsert(_ audio: AudioBuffer) async {
        do {
            guard audio.durationSeconds > 0.1 else {
                throw LocalVoiceFlowError.invalidAudio("No speech audio was captured.")
            }

            let model = selectedModel ?? modelCatalog.recommendedModel(for: .balanced)!
            let engine = try await preparedEngine(for: model)

            let asrWatch = Stopwatch()
            let result = try await engine.transcribeFinal(buffer: audio)
            await performanceLogger.setSpeechEndToFinalASR(asrWatch.elapsedSeconds())

            let cleanupWatch = Stopwatch()
            let profile = resolvedProfile(for: targetApplication)
            activeDictationProfile = profile
            let cleaned = TextPostProcessor().process(
                result.text,
                settings: settings.postProcessing,
                profile: profile.profile
            )
            await performanceLogger.setFinalASRToCleanup(cleanupWatch.elapsedSeconds())

            if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalTranscript = ""
                partialTranscript = ""
                latestMetrics = await performanceLogger.finishCurrent()
                logPerformanceRecord(
                    model: model,
                    profile: profile,
                    audioDuration: audio.durationSeconds,
                    metrics: latestMetrics,
                    error: "Empty transcript"
                )
                lastError = nil
                runtimeState = .finished
                syncOverlay()
                return
            }

            finalTranscript = cleaned
            partialTranscript = ""
            latestMetrics = await performanceLogger.latest()

            var nonFatalErrors: [String] = []
            let targetAppName = targetApplication?.localizedName ?? NSWorkspace.shared.frontmostApplication?.localizedName
            let record = HistoryRecord(
                finalTranscript: cleaned,
                targetAppName: targetAppName,
                asrModelID: model.id,
                cleanupMode: settings.postProcessing.cleanupMode,
                outputProfile: profile.profile.rawValue,
                latencyMetrics: latestMetrics
            )
            do {
                try historyStore.append(record, respecting: settings.privacy)
                history = (try? historyStore.load()) ?? []
                refreshStorageUsage()
            } catch {
                nonFatalErrors.append("History save failed: \(error.localizedDescription)")
            }

            if settings.dictation.copyToClipboard || settings.dictation.autoPaste {
                let pasteWatch = Stopwatch()
                do {
                    let insertResult = try await textInserter.insertText(
                        cleaned,
                        targetApplication: targetApplication,
                        autoPaste: settings.dictation.autoPaste,
                        restoreClipboard: settings.dictation.restoreClipboardAfterPaste,
                        restoreDelayMilliseconds: settings.dictation.clipboardRestoreDelayMilliseconds
                    )
                    await performanceLogger.setPasteMethod(insertResult.method.rawValue)
                    await performanceLogger.setCleanupToPaste(pasteWatch.elapsedSeconds())
                } catch {
                    nonFatalErrors.append("Text was transcribed and saved, but paste failed: \(error.localizedDescription)")
                    await performanceLogger.setPasteMethod("copyFallback")
                    await performanceLogger.setCleanupToPaste(pasteWatch.elapsedSeconds())
                }
            }
            if let speechEndedAt {
                await performanceLogger.setStopSpeakingToInsertedText(Date().timeIntervalSince(speechEndedAt))
            }

            latestMetrics = await performanceLogger.finishCurrent()
            logPerformanceRecord(
                model: model,
                profile: profile,
                audioDuration: audio.durationSeconds,
                metrics: latestMetrics,
                error: nonFatalErrors.isEmpty ? nil : nonFatalErrors.joined(separator: " ")
            )
            if nonFatalErrors.isEmpty {
                lastError = nil
                runtimeState = .finished
            } else {
                lastError = nonFatalErrors.joined(separator: " ")
                runtimeState = .failed(lastError ?? "Dictation finished with errors.")
            }
            syncOverlay()
        } catch {
            if let model = selectedModel {
                logPerformanceRecord(
                    model: model,
                    profile: activeDictationProfile,
                    audioDuration: audio.durationSeconds,
                    metrics: latestMetrics,
                    error: error.localizedDescription
                )
            }
            fail(error.localizedDescription)
        }
    }

    private func makeASREngine(for model: ASRModelInfo) throws -> any ASREngine {
        if ProcessInfo.processInfo.environment["LOCALVOICEFLOW_USE_MOCK_ASR"] == "1" {
            return MockASREngine()
        }

        switch model.backend {
        case .whisperCpp:
            if settings.models.preferPersistentWhisperServer,
               let serverExecutable = settings.models.whisperServerExecutablePath ?? findWhisperServerExecutable() {
                return WhisperCppServerEngine(
                    serverExecutablePath: serverExecutable,
                    modelStorage: modelStorage,
                    modelPathOverride: settings.models.customASRModelPath
                )
            }

            guard let executable = settings.models.whisperExecutablePath ?? findWhisperExecutable() else {
                throw LocalVoiceFlowError.modelUnavailable("Install whisper.cpp and set the executable path in Advanced settings.")
            }
            return WhisperCppCLIEngine(
                executablePath: executable,
                modelStorage: modelStorage,
                modelPathOverride: settings.models.customASRModelPath
            )
        case .fluidAudio:
            return FluidAudioBatchASREngine()
        case .whisperKit:
            throw LocalVoiceFlowError.modelUnavailable("WhisperKit SDK integration is documented for the Xcode app build. Select a whisper.cpp model for this SwiftPM MVP runner.")
        case .mock:
            return MockASREngine()
        case .sherpaOnnx, .moonshine:
            throw LocalVoiceFlowError.modelUnavailable("\(model.backend.rawValue) is a future backend and is not enabled in the MVP.")
        }
    }

    private func findWhisperExecutable() -> String? {
        [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cpp"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func findWhisperServerExecutable() -> String? {
        [
            "/opt/homebrew/bin/whisper-server",
            "/usr/local/bin/whisper-server"
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func normalizedOptionalPath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func preparedEngine(for model: ASRModelInfo) async throws -> any ASREngine {
        if let cachedASREngine,
           cachedASREngine.modelID == model.id,
           await cachedASREngine.engine.isLoaded {
            return cachedASREngine.engine
        }

        let engine = try makeASREngine(for: model)
        let modelLoadWatch = Stopwatch()
        try await engine.loadModel(model)
        await performanceLogger.setModelLoadTime(modelLoadWatch.elapsedSeconds())

        let warmupWatch = Stopwatch()
        try await engine.warmup()
        await performanceLogger.setModelWarmupTime(warmupWatch.elapsedSeconds())

        cachedASREngine = (model.id, engine)
        return engine
    }

    private func prepareSelectedASRModelIfPossible() async {
        guard let model = selectedModel,
              [.whisperCpp, .fluidAudio].contains(model.backend),
              isModelDownloaded(model)
        else { return }
        do {
            _ = try await preparedEngine(for: model)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func invalidateASREngine() {
        if let cachedASREngine {
            Task { await cachedASREngine.engine.unload() }
        }
        cachedASREngine = nil
    }

    private func observeApplicationActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let self
            else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if app.processIdentifier == NSRunningApplication.current.processIdentifier {
                    self.refreshPermissions()
                } else {
                    self.lastNonLocalVoiceFlowApplication = app
                }
            }
        }
    }

    private func observeTermination() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.shutdown()
            }
        }
    }

    private func preferredTargetApplication() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != NSRunningApplication.current.processIdentifier {
            return frontmost
        }
        return lastNonLocalVoiceFlowApplication
    }

    private func resolvedProfile(for app: NSRunningApplication?) -> ResolvedDictationProfile {
        let appInfo = app.map {
            ForegroundAppInfo(
                bundleIdentifier: $0.bundleIdentifier,
                localizedName: $0.localizedName
            )
        }
        return appProfileResolver.resolve(app: appInfo, settings: settings.postProcessing)
    }

    private func shutdown() {
        audioCapture.stop()
        voiceLevel = 0
        voiceBrightness = 0
        voiceSpectrum = .silent
        if let cachedASREngine {
            Task { await cachedASREngine.engine.unload() }
        }
        cachedASREngine = nil
    }

    private func normalizeSettingsForImplementedBackend() {
        var didChangeSettings = false
        if settings.dictation.shortcut == .legacyDefault {
            settings.dictation.shortcut = .default
            didChangeSettings = true
        }

        let mergedReplacements = CustomReplacement.mergingDefaults(with: settings.postProcessing.customReplacements)
        if mergedReplacements != settings.postProcessing.customReplacements {
            settings.postProcessing.customReplacements = mergedReplacements
            didChangeSettings = true
        }

        guard let model = modelCatalog.model(id: settings.models.selectedASRModelID) else {
            settings.models.selectedASRModelID = modelCatalog.recommendedModel(for: .balanced)?.id ?? "whispercpp-base-en-q5"
            settings.models.selectedASRMode = .balanced
            invalidateASREngine()
            try? settingsStore.save(settings)
            return
        }

        if ![ASRBackend.whisperCpp, .fluidAudio].contains(model.backend) {
            settings.models.selectedASRModelID = modelCatalog.recommendedModel(for: .balanced)?.id ?? "whispercpp-base-en-q5"
            settings.models.selectedASRMode = .balanced
            didChangeSettings = true
            invalidateASREngine()
        }

        if didChangeSettings {
            try? settingsStore.save(settings)
        }
    }

    private func mergeLearnedEntries(_ entries: [UserDictionaryEntry]) {
        guard !entries.isEmpty else { return }
        var existing = settings.postProcessing.userDictionary
        var existingKeys = Set(existing.map { normalizedDictionaryKey($0.spokenForm) })
        for entry in entries {
            let key = normalizedDictionaryKey(entry.spokenForm)
            guard !key.isEmpty, !existingKeys.contains(key) else { continue }
            existingKeys.insert(key)
            existing.append(entry)
        }
        settings.postProcessing.userDictionary = existing
    }

    private func normalizedDictionaryKey(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureSilenceDetector() {
        let frameMilliseconds = 30
        let frames = max(1, settings.dictation.silenceDurationMilliseconds / frameMilliseconds)
        silenceDetector = SilenceDetector(requiredSilentFrames: frames)
    }

    private func registerHotkey() {
        hotkeyManager = HotkeyManager()
        do {
            try hotkeyManager?.register(
                shortcut: settings.dictation.shortcut,
                triggerMode: settings.dictation.triggerMode,
                holdThresholdMilliseconds: settings.dictation.holdControlThresholdMilliseconds,
                doubleTapIntervalMilliseconds: settings.dictation.doubleTapControlIntervalMilliseconds,
                onToggle: { [weak self] in
                    self?.dictationRequestedAt = Date()
                    self?.toggleDictation()
                },
                onStart: { [weak self] in
                    guard let self else { return }
                    self.dictationRequestedAt = Date()
                    self.startDictation()
                },
                onStop: { [weak self] in
                    self?.stopDictation()
                }
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fail(_ message: String) {
        lastError = message
        runtimeState = .failed(message)
        partialTranscript = ""
        voiceLevel = 0
        voiceBrightness = 0
        voiceSpectrum = .silent
        syncOverlay()
    }

    private func updateVoiceLevel(_ samples: [Float]) {
        guard !samples.isEmpty else {
            voiceLevel *= 0.82
            voiceBrightness *= 0.82
            voiceSpectrum = voiceSpectrum.smoothed(toward: .silent, attack: 0.34, release: 0.22)
            return
        }

        var sumSquares: Double = 0
        var peak: Double = 0
        var zeroCrossings = 0
        var previousSample = samples[0]
        for sample in samples {
            let value = Double(sample)
            sumSquares += value * value
            peak = max(peak, abs(value))
            if (previousSample < 0 && sample >= 0) || (previousSample >= 0 && sample < 0) {
                zeroCrossings += 1
            }
            previousSample = sample
        }

        let rms = sqrt(sumSquares / Double(samples.count))
        let rmsLevel = normalizedAudioLevel(rms, floor: 0.0035, ceiling: 0.055)
        let peakLevel = normalizedAudioLevel(peak, floor: 0.02, ceiling: 0.22)
        let target = min(1, max(rmsLevel, peakLevel * 0.55))
        let smoothing = target > voiceLevel ? 0.48 : 0.16
        voiceLevel = (voiceLevel * (1 - smoothing)) + (target * smoothing)

        let spectrumTarget = VoiceSpectrumAnalyzer.analyze(samples: samples).scaled(by: target)
        voiceSpectrum = voiceSpectrum.smoothed(toward: spectrumTarget, attack: 0.42, release: 0.18)

        let crossingRate = Double(zeroCrossings) / Double(max(1, samples.count - 1))
        let brightnessTarget = normalizedAudioLevel(crossingRate, floor: 0.025, ceiling: 0.16)
        let brightnessSmoothing = brightnessTarget > voiceBrightness ? 0.34 : 0.12
        let spectralBrightness = voiceSpectrum.brightness
        let mixedBrightnessTarget = min(1, (brightnessTarget * 0.35) + (spectralBrightness * 0.65))
        voiceBrightness = (voiceBrightness * (1 - brightnessSmoothing)) + (mixedBrightnessTarget * brightnessSmoothing)
    }

    private func normalizedAudioLevel(_ value: Double, floor: Double, ceiling: Double) -> Double {
        guard ceiling > floor else { return 0 }
        return min(1, max(0, (value - floor) / (ceiling - floor)))
    }

    private func syncOverlay() {
        guard settings.dictation.showFloatingOverlay else {
            overlayController.hide()
            return
        }

        overlayController.show(appState: self)

        if runtimeState == .finished {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                guard let self, self.runtimeState == .finished else { return }
                self.runtimeState = .idle
                self.syncOverlay()
            }
        }
    }

    private func requestPartialTranscriptionIfNeeded() {
        guard let model = selectedModel, model.backend == .fluidAudio else { return }
        guard runtimeState == .speechDetected || runtimeState == .partialTranscription else { return }
        guard partialTranscriptTask == nil else { return }

        let now = Date()
        let isFirstPartial = firstPartialTranscriptAt == nil
        let minimumInterval = isFirstPartial ? 0.45 : 0.65
        if let lastPartialRequestedAt, now.timeIntervalSince(lastPartialRequestedAt) < minimumInterval {
            return
        }

        let windowSamples = ringBuffer.readLast(sampleCount: isFirstPartial ? 16_000 * 3 : 16_000 * 5)
        let minimumSampleCount = isFirstPartial ? Int(Double(16_000) * 0.75) : Int(Double(16_000) * 1.2)
        guard windowSamples.count >= minimumSampleCount else { return }

        lastPartialRequestedAt = now
        if isFirstPartial, let recordingStartedAt {
            Task { await performanceLogger.setFirstPartialRequestLatency(now.timeIntervalSince(recordingStartedAt)) }
        }
        let chunkID = partialSequenceNumber
        partialSequenceNumber += 1
        let recordingStartedAt = self.recordingStartedAt

        partialTranscriptTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.partialTranscriptTask = nil }

            do {
                let engine = try await self.preparedEngine(for: model)
                let partialASRWatch = Stopwatch()
                let result = try await engine.transcribeFinal(
                    buffer: AudioBuffer(samples: windowSamples, sampleRate: 16_000)
                )
                let partialASRDuration = partialASRWatch.elapsedSeconds()
                guard !Task.isCancelled else { return }
                guard self.runtimeState == .speechDetected || self.runtimeState == .partialTranscription else { return }

                let cleanedPartial = RepetitionReducer().process(ASRArtifactCleaner().process(result.text))
                guard !cleanedPartial.isEmpty else { return }

                let partial = self.partialStabilizer.observe(cleanedPartial, chunkID: chunkID)
                self.partialTranscript = partial.text
                self.runtimeState = .partialTranscription

                if self.firstPartialTranscriptAt == nil {
                    let partialAt = Date()
                    self.firstPartialTranscriptAt = partialAt
                    await self.performanceLogger.setFirstPartialASRDuration(partialASRDuration)
                    if let recordingStartedAt {
                        await self.performanceLogger.setFirstPartialLatency(
                            partialAt.timeIntervalSince(recordingStartedAt)
                        )
                    }
                }
                self.syncOverlay()
            } catch {
                // Partial transcription is best-effort. Final transcription remains authoritative.
            }
        }
    }

    private func logPerformanceRecord(
        model: ASRModelInfo,
        profile: ResolvedDictationProfile,
        audioDuration: TimeInterval,
        metrics: LatencyMetrics,
        error: String?
    ) {
        guard settings.privacy.savePerformanceLogs else { return }
        let shouldIncludeTargetApp = !settings.privacy.privacyMode && settings.privacy.includeTargetAppInLogs
        let shouldIncludeTargetBundle = !settings.privacy.privacyMode && settings.privacy.includeTargetBundleIdentifierInLogs
        let record = PerformanceLogRecord(
            triggerMode: settings.dictation.triggerMode.rawValue,
            asrBackend: model.backend.rawValue,
            modelID: model.id,
            outputProfile: profile.profile.rawValue,
            targetAppName: shouldIncludeTargetApp ? profile.targetAppName : nil,
            targetBundleIdentifier: shouldIncludeTargetBundle ? profile.targetBundleIdentifier : nil,
            streamingMode: model.backend == .fluidAudio ? "pseudoStreaming" : "finalOnly",
            durationRecorded: audioDuration,
            metrics: metrics,
            pasteMethod: metrics.pasteMethod,
            error: error
        )
        try? performanceLogStore.append(record)
        refreshStorageUsage()
    }

    private func fluidAudioSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("FluidAudio", isDirectory: true)
    }

    private func byteCount(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        if !isDirectory.boolValue {
            return fileByteCount(url)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += fileByteCount(fileURL)
        }
        return total
    }

    private func fileByteCount(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
              values.isRegularFile == true
        else {
            return 0
        }

        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    private func lineCount(at url: URL) -> Int {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return 0 }
        return data.reduce(0) { count, byte in byte == 0x0A ? count + 1 : count }
    }
}
