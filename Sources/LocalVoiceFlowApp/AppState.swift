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

    var isCapturing: Bool {
        switch self {
        case .listening, .speechDetected, .partialTranscription:
            true
        case .idle, .processing, .finished, .failed:
            false
        }
    }

    var shouldPresentFloatingOverlay: Bool {
        switch self {
        case .idle, .finished:
            false
        case .listening, .speechDetected, .partialTranscription, .processing, .failed:
            true
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

struct ModelDownloadStatus: Equatable {
    var progress: Double
    var startedAt: Date
    var updatedAt: Date
    var estimatedBytes: Int64
    var downloadedBytes: Int64
    var speedBytesPerSecond: Double?
    var etaSeconds: TimeInterval?
    var phaseText: String?

    var detailText: String {
        if let phaseText {
            return phaseText
        }

        guard let speedBytesPerSecond, speedBytesPerSecond > 1 else {
            return progress > 0 ? "Measuring speed..." : "Connecting..."
        }

        let speed = Self.formatSpeed(speedBytesPerSecond)
        guard let etaSeconds, progress < 0.995 else {
            return "\(speed) - finishing"
        }

        return "\(speed) - \(Self.formatDuration(etaSeconds)) left"
    }

    private static func formatSpeed(_ bytesPerSecond: Double) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(bytesPerSecond.rounded()),
            countStyle: .file
        ) + "/s"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let clamped = max(1, Int(seconds.rounded(.up)))
        if clamped < 60 {
            return "\(clamped)s"
        }

        let minutes = Int(ceil(Double(clamped) / 60.0))
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
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
    @Published var downloadingModelID: String?
    @Published var modelDownloadProgress: [String: Double] = [:]
    @Published var modelDownloadStatus: [String: ModelDownloadStatus] = [:]
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
    @Published var availableUpdate: AppUpdateManifest?
    @Published var updateStatusMessage: String?
    @Published var isCheckingForUpdates = false
    @Published var isInstallingUpdate = false

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
    private let updateInstaller = AppUpdateInstaller()
    private let permissions = PermissionsManager()
    private let performanceLogger = PerformanceLogger()
    private let overlayController = FloatingOverlayController()
    private var ringBuffer = AudioRingBuffer(capacity: 16_000 * 90)
    private var chunkScheduler = ChunkScheduler()
    private var vad = VoiceActivityDetector()
    private var silenceDetector = SilenceDetector(requiredSilentFrames: 24)
    private var hotkeyManager: HotkeyManager?
    private var hotkeyRegistrationError: String?
    private var dictationRequestedAt: Date?
    private var recordingStartedAt: Date?
    private var speechEndedAt: Date?
    private var firstSpeechDetectedAt: Date?
    private var firstPartialTranscriptAt: Date?
    private var cachedASREngine: (modelID: String, engine: any ASREngine)?
    private var modelPreparationTask: Task<Void, Never>?
    private var modelSelectionRevision = 0
    private var targetApplication: NSRunningApplication?
    private var lastNonLocalVoiceFlowApplication: NSRunningApplication?
    private var partialTranscriptTask: Task<Void, Never>?
    private var lastPartialRequestedAt: Date?
    private var partialStabilizer = PartialTranscriptStabilizer(requiredRepeats: 2)
    private var partialSequenceNumber = 0
    private var finishedResetWorkItem: DispatchWorkItem?
    private var hotkeyRegisteredSuccessfully = false

    init() {
        fileStore = LocalFileStore()
        settingsStore = SettingsStore(directory: fileStore.settingsDirectory)
        historyStore = HistoryStore(directory: fileStore.historyDirectory)
        performanceLogStore = PerformanceLogStore(directory: fileStore.logsDirectory)
        correctionStore = CorrectionStore(directory: fileStore.learningDirectory)
        modelStorage = ModelStorage(directory: fileStore.modelsDirectory)

        try? fileStore.prepareDirectories()
        _ = TempAudioFileManager().removeStaleTemporaryFiles()
        settings = (try? settingsStore.load()) ?? .default
        applyBundledUpdateManifestURLIfNeeded()
        normalizeSettingsForImplementedBackend()
        migrateVoiceBarsDefaultIfNeeded()
        migrateFastHoldControlDefaultIfNeeded()
        history = (try? historyStore.load()) ?? []
        correctionRecords = (try? correctionStore.load()) ?? []
        improvementStats = (try? correctionStore.stats()) ?? ImprovementStats()
        storageMigrationStatus = DataStorageMigrationService().status(currentRootDirectory: fileStore.rootDirectory)
        refreshStorageUsage()

        refreshPermissions()
        configureSilenceDetector()
        registerHotkey()
        observeApplicationActivation()
        observeAppLifecyclePermissionRefresh()
        observeTermination()
        Task { @MainActor [weak self] in
            self?.syncOverlay()
        }
        scheduleSelectedModelPreparation()
        Task { await checkForUpdates(manual: false) }
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
        guard let model = modelCatalog.model(id: settings.models.selectedASRModelID),
              isSelectableASRModel(model),
              isModelDownloaded(model)
        else { return nil }
        return model
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

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var appBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? AppBrand.bundleIdentifier
    }

    var shouldShowUpdateAnnouncement: Bool {
        guard let availableUpdate else { return false }
        return settings.updates.dismissedVersion != availableUpdate.version
    }

    func refreshPermissions() {
        let previousAccessibilityPermission = accessibilityPermission
        microphonePermission = permissions.microphonePermissionState()
        let polledAccessibilityPermission = permissions.accessibilityPermissionState()
        accessibilityPermission = effectiveAccessibilityPermission(polledAccessibilityPermission)
        if hotkeyManager != nil,
           previousAccessibilityPermission != .granted,
           accessibilityPermission == .granted {
            registerHotkey()
        }
    }

    func requestMicrophonePermission() {
        Task {
            microphonePermission = await permissions.requestMicrophonePermission()
        }
    }

    func requestAccessibilityPermission() {
        let requestedPermission = permissions.requestAccessibilityPermission()
        accessibilityPermission = effectiveAccessibilityPermission(requestedPermission)
        if accessibilityPermission == .granted {
            registerHotkey()
        } else {
            permissions.openAccessibilitySettings()
        }
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
            playDictationSound(.start)
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
        guard runtimeState.isCapturing else { return }
        audioCapture.stop()
        voiceLevel = 0
        voiceBrightness = 0
        voiceSpectrum = .silent
        partialTranscriptTask?.cancel()
        partialTranscriptTask = nil
        runtimeState = .processing
        playDictationSound(.stop)
        syncOverlay()
        speechEndedAt = Date()

        let audio = AudioBuffer(samples: ringBuffer.snapshot(), sampleRate: 16_000)
        Task {
            await transcribeAndInsert(audio)
        }
    }

    @discardableResult
    func selectModel(_ model: ASRModelInfo) -> Bool {
        guard isModelRuntimeAvailable(model) else {
            modelDownloadMessage = "\(model.displayName) needs an external runtime before Scrivora can use it. Use Parakeet for the built-in local path."
            return false
        }
        guard isModelDownloaded(model) else {
            modelDownloadMessage = "Download \(model.displayName) before using it."
            return false
        }
        settings.models.selectedASRModelID = model.id
        settings.models.selectedASRMode = model.mode
        invalidateASREngine()
        saveSettings()
        scheduleSelectedModelPreparation()
        return true
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

    func isModelDownloading(_ model: ASRModelInfo) -> Bool {
        downloadingModelID == model.id
    }

    func downloadProgress(for model: ASRModelInfo) -> Double? {
        modelDownloadProgress[model.id]
    }

    func downloadStatus(for model: ASRModelInfo) -> ModelDownloadStatus? {
        modelDownloadStatus[model.id]
    }

    private func beginModelDownload(_ model: ASRModelInfo) {
        let now = Date()
        modelDownloadProgress[model.id] = 0
        modelDownloadStatus[model.id] = ModelDownloadStatus(
            progress: 0,
            startedAt: now,
            updatedAt: now,
            estimatedBytes: estimatedDownloadBytes(for: model),
            downloadedBytes: 0,
            speedBytesPerSecond: nil,
            etaSeconds: nil,
            phaseText: initialDownloadPhaseText(for: model)
        )
    }

    private func updateModelDownload(_ model: ASRModelInfo, progress rawProgress: Double) {
        let progress = min(1, max(0, rawProgress))
        let now = Date()
        let previous = modelDownloadStatus[model.id]
        let startedAt = previous?.startedAt ?? now
        let estimatedBytes = previous?.estimatedBytes ?? estimatedDownloadBytes(for: model)
        let measuredProgress = measuredDownloadProgress(for: model, progress: progress)
        let downloadedBytes = Int64((Double(estimatedBytes) * measuredProgress).rounded(.down))
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        let averageSpeed = elapsed >= 0.75 && downloadedBytes > 0 && measuredProgress < 0.995
            ? Double(downloadedBytes) / elapsed
            : nil

        let speed = averageSpeed ?? previous?.speedBytesPerSecond
        let phaseText = downloadPhaseText(for: model, progress: progress)
        let remainingBytes = max(0, estimatedBytes - downloadedBytes)
        let eta = phaseText == nil ? speed.flatMap { value -> TimeInterval? in
            guard value > 1, measuredProgress < 0.995 else { return nil }
            return Double(remainingBytes) / value
        } : nil

        modelDownloadProgress[model.id] = progress
        modelDownloadStatus[model.id] = ModelDownloadStatus(
            progress: progress,
            startedAt: startedAt,
            updatedAt: now,
            estimatedBytes: estimatedBytes,
            downloadedBytes: downloadedBytes,
            speedBytesPerSecond: speed,
            etaSeconds: eta,
            phaseText: phaseText
        )
    }

    private func estimatedDownloadBytes(for model: ASRModelInfo) -> Int64 {
        Int64(max(1, model.estimatedSizeMB)) * 1_000_000
    }

    private func initialDownloadPhaseText(for model: ASRModelInfo) -> String? {
        switch model.backend {
        case .fluidAudio:
            return "Preparing local model..."
        case .whisperCpp, .whisperKit, .mock, .sherpaOnnx, .moonshine:
            return nil
        }
    }

    private func downloadPhaseText(for model: ASRModelInfo, progress: Double) -> String? {
        switch model.backend {
        case .fluidAudio:
            if progress < 0.10 { return "Preparing local model..." }
            if progress >= 0.90 && progress < 0.995 { return "Verifying local files..." }
            if progress >= 0.995 { return "Finishing..." }
            return nil
        case .whisperCpp:
            if progress >= 0.995 { return "Finishing..." }
            return nil
        case .whisperKit, .mock, .sherpaOnnx, .moonshine:
            return nil
        }
    }

    private func measuredDownloadProgress(for model: ASRModelInfo, progress: Double) -> Double {
        switch model.backend {
        case .fluidAudio:
            if progress <= 0.10 { return 0 }
            if progress >= 0.90 { return 1 }
            return min(1, max(0, (progress - 0.10) / 0.78))
        case .whisperCpp:
            return progress
        case .whisperKit, .mock, .sherpaOnnx, .moonshine:
            return progress
        }
    }

    var isWhisperRuntimeAvailable: Bool {
        resolvedWhisperExecutable() != nil || resolvedWhisperServerExecutable() != nil
    }

    func isModelRuntimeAvailable(_ model: ASRModelInfo) -> Bool {
        switch model.backend {
        case .fluidAudio, .mock:
            true
        case .whisperCpp:
            isWhisperRuntimeAvailable
        case .whisperKit, .sherpaOnnx, .moonshine:
            false
        }
    }

    func shouldShowModelInStandardPicker(_ model: ASRModelInfo) -> Bool {
        switch model.backend {
        case .fluidAudio:
            return true
        case .whisperCpp:
            return isWhisperRuntimeAvailable
        case .whisperKit, .mock, .sherpaOnnx, .moonshine:
            return false
        }
    }

    func setPreferPersistentWhisperServer(_ enabled: Bool) {
        settings.models.preferPersistentWhisperServer = enabled
        invalidateASREngine()
        saveSettings()
        scheduleSelectedModelPreparation()
    }

    func setWhisperServerPath(_ path: String) {
        settings.models.whisperServerExecutablePath = normalizedOptionalPath(path)
        invalidateASREngine()
        saveSettings()
        scheduleSelectedModelPreparation()
    }

    func setWhisperExecutablePath(_ path: String) {
        settings.models.whisperExecutablePath = normalizedOptionalPath(path)
        invalidateASREngine()
        saveSettings()
        scheduleSelectedModelPreparation()
    }

    func setCustomASRModelPath(_ path: String) {
        settings.models.customASRModelPath = normalizedOptionalPath(path)
        invalidateASREngine()
        saveSettings()
        scheduleSelectedModelPreparation()
    }

    func downloadModel(_ model: ASRModelInfo) {
        guard downloadingModelID == nil else {
            modelDownloadMessage = "Finish the current model download before starting another."
            return
        }

        guard NetworkAccessPolicy.canDownloadRemoteModel(privacy: settings.privacy) else {
            modelDownloadMessage = "Offline Mode is on. Scrivora will only use local models and local services. Remote model downloads are disabled."
            return
        }

        guard model.backend == .fluidAudio || model.downloadURL != nil else {
            modelDownloadMessage = "No direct download is configured for \(model.displayName)."
            return
        }

        guard isModelRuntimeAvailable(model) else {
            modelDownloadMessage = "\(model.displayName) needs whisper.cpp before it can run. Use Parakeet, or install whisper.cpp first."
            return
        }

        modelDownloadMessage = "Downloading \(model.displayName)..."
        downloadingModelID = model.id
        beginModelDownload(model)
        Task {
            defer {
                downloadingModelID = nil
                modelDownloadProgress[model.id] = nil
                modelDownloadStatus[model.id] = nil
            }
            do {
                switch model.backend {
                case .whisperCpp:
                    _ = try await ModelDownloader().download(model: model, to: modelStorage) { [weak self] progress in
                        Task { @MainActor in
                            self?.updateModelDownload(model, progress: progress)
                        }
                    }
                case .fluidAudio:
                    _ = try await FluidAudioModelSupport.download(model) { [weak self] progress in
                        Task { @MainActor in
                            self?.updateModelDownload(model, progress: progress)
                        }
                    }
                default:
                    throw LocalVoiceFlowError.modelUnavailable("Direct app download is enabled for whisper.cpp and FluidAudio Parakeet models.")
                }
                if selectModel(model) {
                    modelDownloadMessage = "Downloaded and selected \(model.displayName)."
                }
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
                if repairSelectedASRModelIfNeeded(showMessage: true) {
                    scheduleSelectedModelPreparation()
                }
            }
            modelDownloadProgress[model.id] = nil
            modelDownloadStatus[model.id] = nil
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
                fluidAudioDirectory: fluidAudioModelsDirectory()
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
        let fluidAudioRoot = fluidAudioModelsDirectory()
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

    func openWhisperModelFolder() {
        try? FileManager.default.createDirectory(at: fileStore.modelsDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([fileStore.modelsDirectory])
    }

    func openFluidAudioModelFolder() {
        let directory = fluidAudioModelsDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    func clearWhisperModels() {
        clearDirectoryContents(fileStore.modelsDirectory, message: "Whisper model cache cleared.")
    }

    func clearFluidAudioModelCache() {
        clearDirectoryContents(fluidAudioModelsDirectory(), message: "FluidAudio model cache cleared.")
    }

    func setAutomaticUpdateChecks(_ enabled: Bool) {
        settings.updates.automaticChecksEnabled = enabled
        saveSettings()
    }

    func setUpdateManifestURL(_ value: String) {
        settings.updates.manifestURLString = value.trimmingCharacters(in: .whitespacesAndNewlines)
        saveSettings()
    }

    func setIncludePrereleaseUpdates(_ enabled: Bool) {
        settings.updates.includePrerelease = enabled
        saveSettings()
    }

    func dismissUpdateAnnouncement() {
        guard let availableUpdate else { return }
        settings.updates.dismissedVersion = availableUpdate.version
        saveSettings()
    }

    func checkForUpdates(manual: Bool) async {
        guard manual || settings.updates.automaticChecksEnabled else { return }
        guard let manifestURL = updateManifestURL() else {
            if manual {
                updateStatusMessage = "Update feed is unavailable. Open scrivora.me/releases for the latest build."
            }
            return
        }
        guard manifestURL.isFileURL || NetworkAccessPolicy.canCheckRemoteUpdates(privacy: settings.privacy) else {
            updateStatusMessage = "Offline Mode is on. Remote update checks are disabled."
            return
        }

        isCheckingForUpdates = true
        updateStatusMessage = manual ? "Checking for updates..." : updateStatusMessage
        defer { isCheckingForUpdates = false }

        do {
            let manifest = try await updateInstaller.fetchManifest(from: manifestURL)
            settings.updates.lastCheckedAt = Date()

            let channel = manifest.channel.lowercased()
            if channel.contains("pre") || channel.contains("beta") {
                guard settings.updates.includePrerelease else {
                    availableUpdate = nil
                    updateStatusMessage = manual
                        ? "A \(manifest.channel) update is available, but prerelease updates are off."
                        : updateStatusMessage
                    saveSettings()
                    return
                }
            }

            if AppUpdateVersionComparator.isVersion(manifest.version, newerThan: appVersion) {
                availableUpdate = manifest
                updateStatusMessage = "Scrivora \(manifest.version) is available."
            } else {
                availableUpdate = nil
                updateStatusMessage = manual ? "Scrivora is up to date." : updateStatusMessage
            }
            saveSettings()
        } catch {
            updateStatusMessage = error.localizedDescription
        }
    }

    func installAvailableUpdate() {
        guard let availableUpdate else {
            updateStatusMessage = "No update is available."
            return
        }
        guard AppBrand.updateDeveloperTeamIdentifier != nil else {
            updateStatusMessage = "Open the release page to download the latest DMG."
            openAvailableUpdateReleaseNotes()
            return
        }
        guard !isInstallingUpdate else { return }

        isInstallingUpdate = true
        updateStatusMessage = "Downloading Scrivora \(availableUpdate.version)..."

        Task {
            do {
                let prepared = try await updateInstaller.prepareUpdate(
                    availableUpdate,
                    expectedBundleIdentifier: appBundleIdentifier,
                    currentVersion: appVersion
                )
                updateStatusMessage = "Installing Scrivora \(availableUpdate.version)..."
                try updateInstaller.launchInstaller(for: prepared)
                updateStatusMessage = "Relaunching Scrivora..."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NSApp.terminate(nil)
                }
            } catch {
                isInstallingUpdate = false
                updateStatusMessage = error.localizedDescription
            }
        }
    }

    func openAvailableUpdateReleaseNotes() {
        guard let url = availableUpdate?.releaseNotesURL else { return }
        NSWorkspace.shared.open(url)
    }

    func saveSettings() {
        do {
            try settingsStore.save(settings)
            configureSilenceDetector()
            registerHotkey()
            syncOverlay()
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

        if settings.dictation.shouldObserveSilenceAutoStop, silenceDetector.observe(isSpeech: isSpeech) {
            stopDictation()
        }
    }

    private func transcribeAndInsert(_ audio: AudioBuffer) async {
        do {
            guard audio.durationSeconds > 0.1 else {
                throw LocalVoiceFlowError.invalidAudio("No speech audio was captured.")
            }

            if repairSelectedASRModelIfNeeded(showMessage: true) {
                scheduleSelectedModelPreparation()
            }
            guard let model = selectedModel else {
                throw LocalVoiceFlowError.modelUnavailable("Download a speech model before dictating.")
            }
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
                let pasteStartedAt = Date()
                do {
                    let focusedAtEnd = NSWorkspace.shared.frontmostApplication.flatMap { app in
                        app.processIdentifier == NSRunningApplication.current.processIdentifier ? nil : app
                    }
                    let insertResult = try await textInserter.insertText(
                        cleaned,
                        startApplication: targetApplication,
                        endApplication: focusedAtEnd,
                        autoPaste: settings.dictation.autoPaste,
                        pasteTargetBehavior: settings.dictation.pasteTargetBehavior,
                        pasteStrategy: settings.dictation.restoreClipboardAfterPaste ? settings.dictation.pasteStrategy : .instant,
                        customRestoreDelayMilliseconds: settings.dictation.clipboardRestoreDelayMilliseconds
                    )
                    await performanceLogger.setPastePipelineMetrics(insertResult.metrics)
                    await performanceLogger.setCleanupToPaste(insertResult.metrics.visibleInsertLatency ?? pasteWatch.elapsedSeconds())
                    if let speechEndedAt, let visibleInsertLatency = insertResult.metrics.visibleInsertLatency {
                        await performanceLogger.setUserVisibleStopToInsertLatency(
                            pasteStartedAt.addingTimeInterval(visibleInsertLatency).timeIntervalSince(speechEndedAt)
                        )
                    }
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
               let serverExecutable = resolvedWhisperServerExecutable() {
                return WhisperCppServerEngine(
                    serverExecutablePath: serverExecutable,
                    modelStorage: modelStorage,
                    modelPathOverride: settings.models.customASRModelPath
                )
            }

            guard let executable = resolvedWhisperExecutable() else {
                throw LocalVoiceFlowError.modelUnavailable("Whisper needs whisper.cpp before it can run. Use a Parakeet model for the built-in local path.")
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

    private func resolvedWhisperExecutable() -> String? {
        executablePath(settings.models.whisperExecutablePath) ?? findWhisperExecutable()
    }

    private func resolvedWhisperServerExecutable() -> String? {
        executablePath(settings.models.whisperServerExecutablePath) ?? findWhisperServerExecutable()
    }

    private func executablePath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }
        return path
    }

    private func normalizedOptionalPath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func updateManifestURL() -> URL? {
        let value = settings.updates.manifestURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }
        return URL(string: value)
    }

    private func applyBundledUpdateManifestURLIfNeeded() {
        guard settings.updates.manifestURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let bundledValue = Bundle.main.object(forInfoDictionaryKey: "ScrivoraUpdateManifestURL") as? String
        let trimmedBundledValue = bundledValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedValue = trimmedBundledValue.isEmpty ? AppBrand.updateManifestURL : trimmedBundledValue
        settings.updates.manifestURLString = resolvedValue
        try? settingsStore.save(settings)
    }

    private func migrateVoiceBarsDefaultIfNeeded() {
        let migrationKey = "scrivora.migrations.voiceBarsDefault.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if settings.dictation.floatingOverlayStyle != .voiceBars ||
            settings.dictation.floatingOverlayPalette != .scrivora {
            settings.dictation.floatingOverlayStyle = .voiceBars
            settings.dictation.floatingOverlayPalette = .scrivora
            settings.dictation.floatingOverlayPlacement = .bottom
            try? settingsStore.save(settings)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func migrateFastHoldControlDefaultIfNeeded() {
        let migrationKey = "scrivora.migrations.fastHoldControlDefault.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if settings.dictation.holdControlThresholdMilliseconds == 150 {
            settings.dictation.holdControlThresholdMilliseconds = 80
            try? settingsStore.save(settings)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
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

        if settings.models.selectedASRModelID == model.id,
           isModelDownloaded(model) {
            cachedASREngine = (model.id, engine)
        }
        return engine
    }

    private func scheduleSelectedModelPreparation() {
        modelSelectionRevision += 1
        let revision = modelSelectionRevision
        modelPreparationTask?.cancel()
        modelPreparationTask = Task { @MainActor [weak self] in
            await self?.prepareSelectedASRModelIfPossible(revision: revision)
        }
    }

    private func prepareSelectedASRModelIfPossible(revision: Int) async {
        if repairSelectedASRModelIfNeeded(showMessage: false) {
            scheduleSelectedModelPreparation()
            return
        }

        guard let model = selectedModel,
              isModelDownloaded(model)
        else { return }
        let modelID = model.id
        do {
            let engine = try await preparedEngine(for: model)
            guard !Task.isCancelled,
                  revision == modelSelectionRevision,
                  settings.models.selectedASRModelID == modelID
            else {
                if cachedASREngine?.modelID != modelID {
                    await engine.unload()
                }
                return
            }
            lastError = nil
        } catch {
            guard !Task.isCancelled,
                  revision == modelSelectionRevision,
                  settings.models.selectedASRModelID == modelID
            else { return }
            lastError = error.localizedDescription
        }
    }

    private func invalidateASREngine() {
        modelSelectionRevision += 1
        modelPreparationTask?.cancel()
        modelPreparationTask = nil
        if let cachedASREngine {
            Task { await cachedASREngine.engine.unload() }
        }
        cachedASREngine = nil
    }

    private enum DictationSound {
        case start
        case stop

        var systemName: NSSound.Name {
            switch self {
            case .start: NSSound.Name("Pop")
            case .stop: NSSound.Name("Tink")
            }
        }
    }

    private func playDictationSound(_ sound: DictationSound) {
        guard settings.dictation.startStopSound else { return }
        if let sound = NSSound(named: sound.systemName) {
            sound.play()
        } else {
            NSSound.beep()
        }
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

    private func observeAppLifecyclePermissionRefresh() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPermissions()
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

        if didChangeSettings {
            try? settingsStore.save(settings)
        }

        _ = repairSelectedASRModelIfNeeded(showMessage: false)
    }

    @discardableResult
    private func repairSelectedASRModelIfNeeded(showMessage: Bool) -> Bool {
        if let model = modelCatalog.model(id: settings.models.selectedASRModelID),
           isSelectableASRModel(model),
           isModelDownloaded(model) {
            return false
        }

        let previousModelName = modelCatalog.model(id: settings.models.selectedASRModelID)?.displayName
            ?? settings.models.selectedASRModelID
        let availableIDs = Set(modelCatalog.models
            .filter { isSelectableASRModel($0) && isModelDownloaded($0) }
            .map(\.id))

        guard let fallback = modelCatalog.bestAvailableASRModel(
            preferredMode: settings.models.selectedASRMode,
            availableIDs: availableIDs
        ) else {
            if showMessage {
                modelDownloadMessage = "Download a speech model before dictating."
            }
            return false
        }

        settings.models.selectedASRModelID = fallback.id
        settings.models.selectedASRMode = fallback.mode
        invalidateASREngine()
        try? settingsStore.save(settings)

        if showMessage {
            modelDownloadMessage = "Switched to \(fallback.displayName) because \(previousModelName) is unavailable."
        }
        return true
    }

    private func isSelectableASRModel(_ model: ASRModelInfo) -> Bool {
        isModelRuntimeAvailable(model)
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
        hotkeyRegisteredSuccessfully = false
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
            if let hotkeyRegistrationError, lastError == hotkeyRegistrationError {
                lastError = nil
            }
            hotkeyRegisteredSuccessfully = true
            if hotkeyRegistrationImpliesAccessibilityTrust {
                accessibilityPermission = .granted
            }
            hotkeyRegistrationError = nil
        } catch {
            hotkeyRegisteredSuccessfully = false
            let message = error.localizedDescription
            hotkeyRegistrationError = message
            lastError = message
        }
    }

    private func effectiveAccessibilityPermission(_ polledPermission: PermissionState) -> PermissionState {
        if polledPermission == .granted {
            return .granted
        }
        if hotkeyRegistrationImpliesAccessibilityTrust {
            return .granted
        }
        return polledPermission
    }

    private var hotkeyRegistrationImpliesAccessibilityTrust: Bool {
        hotkeyRegisteredSuccessfully
            && (settings.dictation.triggerMode != .globalShortcut || settings.dictation.shortcut.isControlTap)
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
        scheduleFinishedResetIfNeeded()

        guard settings.dictation.showFloatingOverlay,
              runtimeState.shouldPresentFloatingOverlay
        else {
            overlayController.hide()
            return
        }

        overlayController.show(appState: self)
    }

    private func scheduleFinishedResetIfNeeded() {
        guard runtimeState == .finished else {
            finishedResetWorkItem?.cancel()
            finishedResetWorkItem = nil
            return
        }
        guard finishedResetWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.runtimeState == .finished else { return }
            self.finishedResetWorkItem = nil
            self.runtimeState = .idle
            self.syncOverlay()
        }
        finishedResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
    }

    private func requestPartialTranscriptionIfNeeded() {
        if repairSelectedASRModelIfNeeded(showMessage: false) {
            scheduleSelectedModelPreparation()
            return
        }

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
        var exportedMetrics = metrics
        if !shouldIncludeTargetApp {
            exportedMetrics.pasteTargetAppName = nil
        }
        if !shouldIncludeTargetBundle {
            exportedMetrics.pasteTargetBundleIdentifier = nil
        }
        let record = PerformanceLogRecord(
            triggerMode: settings.dictation.triggerMode.rawValue,
            asrBackend: model.backend.rawValue,
            modelID: model.id,
            outputProfile: profile.profile.rawValue,
            targetAppName: shouldIncludeTargetApp ? profile.targetAppName : nil,
            targetBundleIdentifier: shouldIncludeTargetBundle ? profile.targetBundleIdentifier : nil,
            streamingMode: model.backend == .fluidAudio ? "pseudoStreaming" : "finalOnly",
            durationRecorded: audioDuration,
            metrics: exportedMetrics,
            pasteMethod: exportedMetrics.pasteMethod,
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

    private func fluidAudioModelsDirectory() -> URL {
        fluidAudioSupportDirectory().appendingPathComponent("Models", isDirectory: true)
    }

    private func clearDirectoryContents(_ directory: URL, message: String) {
        do {
            guard FileManager.default.fileExists(atPath: directory.path) else {
                storageStatusMessage = message
                refreshStorageUsage()
                return
            }
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            for url in contents {
                try FileManager.default.removeItem(at: url)
            }
            invalidateASREngine()
            storageStatusMessage = message
            refreshStorageUsage()
        } catch {
            storageStatusMessage = error.localizedDescription
        }
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
