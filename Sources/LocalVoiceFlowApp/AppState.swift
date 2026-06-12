import AppKit
import Foundation
import LocalVoiceFlowCore

enum DictationRuntimeState: Equatable {
    case idle
    case listening
    case speechDetected
    case processing
    case finished
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Idle"
        case .listening: "Listening"
        case .speechDetected: "Speech detected"
        case .processing: "Processing"
        case .finished: "Finished"
        case .failed: "Error"
        }
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

    let fileStore: LocalFileStore
    let modelCatalog = ModelCatalog.default

    private let settingsStore: SettingsStore
    private let historyStore: HistoryStore
    private let modelStorage: ModelStorage
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
    private var cachedASREngine: (modelID: String, engine: any ASREngine)?
    private var targetApplication: NSRunningApplication?
    private var lastNonLocalVoiceFlowApplication: NSRunningApplication?

    init() {
        fileStore = LocalFileStore()
        settingsStore = SettingsStore(directory: fileStore.settingsDirectory)
        historyStore = HistoryStore(directory: fileStore.historyDirectory)
        modelStorage = ModelStorage(directory: fileStore.modelsDirectory)

        try? fileStore.prepareDirectories()
        settings = (try? settingsStore.load()) ?? .default
        normalizeSettingsForImplementedBackend()
        history = (try? historyStore.load()) ?? []

        refreshPermissions()
        configureSilenceDetector()
        registerHotkey()
        observeApplicationActivation()
        observeTermination()
        Task { await prepareSelectedASRModelIfPossible() }
    }

    var menuBarSystemImage: String {
        switch runtimeState {
        case .idle, .finished:
            "waveform"
        case .listening, .speechDetected:
            "mic.fill"
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
        case .listening, .speechDetected:
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
        partialTranscript = ""
        finalTranscript = ""
        lastError = nil
        firstSpeechDetectedAt = nil
        speechEndedAt = nil
        dictationRequestedAt = dictationRequestedAt ?? Date()
        recordingStartedAt = Date()
        targetApplication = preferredTargetApplication()

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

    func clearHistory() {
        do {
            try historyStore.clear()
            history = []
        } catch {
            fail(error.localizedDescription)
        }
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
            partialTranscript = "Listening..."
            syncOverlay()
        } else if runtimeState == .speechDetected {
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
            let cleaned = TextPostProcessor().process(result.text, settings: settings.postProcessing)
            await performanceLogger.setFinalASRToCleanup(cleanupWatch.elapsedSeconds())

            finalTranscript = cleaned
            partialTranscript = ""
            latestMetrics = await performanceLogger.latest()
            refreshPermissions()

            var nonFatalErrors: [String] = []
            let targetAppName = targetApplication?.localizedName ?? NSWorkspace.shared.frontmostApplication?.localizedName
            let record = HistoryRecord(
                finalTranscript: cleaned,
                targetAppName: targetAppName,
                asrModelID: model.id,
                cleanupMode: settings.postProcessing.cleanupMode,
                latencyMetrics: latestMetrics
            )
            do {
                try historyStore.append(record, respecting: settings.privacy)
                history = (try? historyStore.load()) ?? []
            } catch {
                nonFatalErrors.append("History save failed: \(error.localizedDescription)")
            }

            if settings.dictation.copyToClipboard || settings.dictation.autoPaste {
                let pasteWatch = Stopwatch()
                do {
                    try await textInserter.insertText(
                        cleaned,
                        targetApplication: targetApplication,
                        autoPaste: settings.dictation.autoPaste,
                        restoreClipboard: settings.dictation.restoreClipboardAfterPaste
                    )
                    await performanceLogger.setCleanupToPaste(pasteWatch.elapsedSeconds())
                } catch {
                    nonFatalErrors.append("Text was transcribed and saved, but paste failed: \(error.localizedDescription)")
                    await performanceLogger.setCleanupToPaste(pasteWatch.elapsedSeconds())
                }
            }
            if let speechEndedAt {
                await performanceLogger.setStopSpeakingToInsertedText(Date().timeIntervalSince(speechEndedAt))
            }

            latestMetrics = await performanceLogger.finishCurrent()
            if nonFatalErrors.isEmpty {
                lastError = nil
                runtimeState = .finished
            } else {
                lastError = nonFatalErrors.joined(separator: " ")
                runtimeState = .failed(lastError ?? "Dictation finished with errors.")
            }
            syncOverlay()
        } catch {
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

    private func shutdown() {
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

    private func configureSilenceDetector() {
        let frameMilliseconds = 30
        let frames = max(1, settings.dictation.silenceDurationMilliseconds / frameMilliseconds)
        silenceDetector = SilenceDetector(requiredSilentFrames: frames)
    }

    private func registerHotkey() {
        hotkeyManager = HotkeyManager()
        do {
            try hotkeyManager?.register(shortcut: settings.dictation.shortcut) { [weak self] in
                self?.toggleDictation()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fail(_ message: String) {
        lastError = message
        runtimeState = .failed(message)
        partialTranscript = ""
        syncOverlay()
    }

    private func syncOverlay() {
        guard settings.dictation.showFloatingOverlay else {
            overlayController.hide()
            return
        }

        switch runtimeState {
        case .listening, .speechDetected, .processing, .failed:
            overlayController.show(appState: self)
        case .idle, .finished:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.overlayController.hide()
            }
        }
    }
}
