import Foundation

public struct LatencyMetrics: Codable, Equatable, Sendable {
    public var hotkeyToRecordingStart: TimeInterval?
    public var recordingStartToSpeechDetected: TimeInterval?
    public var speechEndToFinalASR: TimeInterval?
    public var finalASRToCleanup: TimeInterval?
    public var cleanupToPaste: TimeInterval?
    public var stopSpeakingToInsertedText: TimeInterval?
    public var firstPartialLatency: TimeInterval?
    public var firstPartialRequestLatency: TimeInterval?
    public var firstPartialASRDuration: TimeInterval?
    public var pasteMethod: String?
    public var pasteTargetBehavior: String?
    public var pasteTargetAppName: String?
    public var pasteTargetBundleIdentifier: String?
    public var pasteFocusChanged: Bool?
    public var pasteFallbackUsed: Bool?
    public var pasteFailureReason: String?
    public var clipboardSnapshotDuration: TimeInterval?
    public var clipboardSetDuration: TimeInterval?
    public var targetFocusCheckDuration: TimeInterval?
    public var commandVPostDuration: TimeInterval?
    public var visibleInsertLatency: TimeInterval?
    public var clipboardRestoreDelay: TimeInterval?
    public var clipboardRestoreDuration: TimeInterval?
    public var totalPastePipelineDuration: TimeInterval?
    public var userVisibleStopToInsertLatency: TimeInterval?
    public var backgroundClipboardRestoreLatency: TimeInterval?
    public var modelLoadTime: TimeInterval?
    public var modelWarmupTime: TimeInterval?

    public init(
        hotkeyToRecordingStart: TimeInterval? = nil,
        recordingStartToSpeechDetected: TimeInterval? = nil,
        speechEndToFinalASR: TimeInterval? = nil,
        finalASRToCleanup: TimeInterval? = nil,
        cleanupToPaste: TimeInterval? = nil,
        stopSpeakingToInsertedText: TimeInterval? = nil,
        firstPartialLatency: TimeInterval? = nil,
        firstPartialRequestLatency: TimeInterval? = nil,
        firstPartialASRDuration: TimeInterval? = nil,
        pasteMethod: String? = nil,
        pasteTargetBehavior: String? = nil,
        pasteTargetAppName: String? = nil,
        pasteTargetBundleIdentifier: String? = nil,
        pasteFocusChanged: Bool? = nil,
        pasteFallbackUsed: Bool? = nil,
        pasteFailureReason: String? = nil,
        clipboardSnapshotDuration: TimeInterval? = nil,
        clipboardSetDuration: TimeInterval? = nil,
        targetFocusCheckDuration: TimeInterval? = nil,
        commandVPostDuration: TimeInterval? = nil,
        visibleInsertLatency: TimeInterval? = nil,
        clipboardRestoreDelay: TimeInterval? = nil,
        clipboardRestoreDuration: TimeInterval? = nil,
        totalPastePipelineDuration: TimeInterval? = nil,
        userVisibleStopToInsertLatency: TimeInterval? = nil,
        backgroundClipboardRestoreLatency: TimeInterval? = nil,
        modelLoadTime: TimeInterval? = nil,
        modelWarmupTime: TimeInterval? = nil
    ) {
        self.hotkeyToRecordingStart = hotkeyToRecordingStart
        self.recordingStartToSpeechDetected = recordingStartToSpeechDetected
        self.speechEndToFinalASR = speechEndToFinalASR
        self.finalASRToCleanup = finalASRToCleanup
        self.cleanupToPaste = cleanupToPaste
        self.stopSpeakingToInsertedText = stopSpeakingToInsertedText
        self.firstPartialLatency = firstPartialLatency
        self.firstPartialRequestLatency = firstPartialRequestLatency
        self.firstPartialASRDuration = firstPartialASRDuration
        self.pasteMethod = pasteMethod
        self.pasteTargetBehavior = pasteTargetBehavior
        self.pasteTargetAppName = pasteTargetAppName
        self.pasteTargetBundleIdentifier = pasteTargetBundleIdentifier
        self.pasteFocusChanged = pasteFocusChanged
        self.pasteFallbackUsed = pasteFallbackUsed
        self.pasteFailureReason = pasteFailureReason
        self.clipboardSnapshotDuration = clipboardSnapshotDuration
        self.clipboardSetDuration = clipboardSetDuration
        self.targetFocusCheckDuration = targetFocusCheckDuration
        self.commandVPostDuration = commandVPostDuration
        self.visibleInsertLatency = visibleInsertLatency
        self.clipboardRestoreDelay = clipboardRestoreDelay
        self.clipboardRestoreDuration = clipboardRestoreDuration
        self.totalPastePipelineDuration = totalPastePipelineDuration
        self.userVisibleStopToInsertLatency = userVisibleStopToInsertLatency
        self.backgroundClipboardRestoreLatency = backgroundClipboardRestoreLatency
        self.modelLoadTime = modelLoadTime
        self.modelWarmupTime = modelWarmupTime
    }
}

public struct PastePipelineMetrics: Codable, Equatable, Sendable {
    public var method: String?
    public var targetBehavior: String?
    public var targetAppName: String?
    public var targetBundleIdentifier: String?
    public var focusChanged: Bool
    public var fallbackUsed: Bool
    public var failureReason: String?
    public var clipboardSnapshotDuration: TimeInterval?
    public var clipboardSetDuration: TimeInterval?
    public var targetFocusCheckDuration: TimeInterval?
    public var commandVPostDuration: TimeInterval?
    public var visibleInsertLatency: TimeInterval?
    public var clipboardRestoreDelay: TimeInterval?
    public var clipboardRestoreDuration: TimeInterval?
    public var totalPastePipelineDuration: TimeInterval?
    public var backgroundClipboardRestoreLatency: TimeInterval?

    public init(
        method: String? = nil,
        targetBehavior: String? = nil,
        targetAppName: String? = nil,
        targetBundleIdentifier: String? = nil,
        focusChanged: Bool = false,
        fallbackUsed: Bool = false,
        failureReason: String? = nil,
        clipboardSnapshotDuration: TimeInterval? = nil,
        clipboardSetDuration: TimeInterval? = nil,
        targetFocusCheckDuration: TimeInterval? = nil,
        commandVPostDuration: TimeInterval? = nil,
        visibleInsertLatency: TimeInterval? = nil,
        clipboardRestoreDelay: TimeInterval? = nil,
        clipboardRestoreDuration: TimeInterval? = nil,
        totalPastePipelineDuration: TimeInterval? = nil,
        backgroundClipboardRestoreLatency: TimeInterval? = nil
    ) {
        self.method = method
        self.targetBehavior = targetBehavior
        self.targetAppName = targetAppName
        self.targetBundleIdentifier = targetBundleIdentifier
        self.focusChanged = focusChanged
        self.fallbackUsed = fallbackUsed
        self.failureReason = failureReason
        self.clipboardSnapshotDuration = clipboardSnapshotDuration
        self.clipboardSetDuration = clipboardSetDuration
        self.targetFocusCheckDuration = targetFocusCheckDuration
        self.commandVPostDuration = commandVPostDuration
        self.visibleInsertLatency = visibleInsertLatency
        self.clipboardRestoreDelay = clipboardRestoreDelay
        self.clipboardRestoreDuration = clipboardRestoreDuration
        self.totalPastePipelineDuration = totalPastePipelineDuration
        self.backgroundClipboardRestoreLatency = backgroundClipboardRestoreLatency
    }
}

public actor PerformanceLogger {
    private var current = LatencyMetrics()
    private var history: [LatencyMetrics] = []

    public init() {}

    public func update(_ transform: (inout LatencyMetrics) -> Void) {
        transform(&current)
    }

    public func setHotkeyToRecordingStart(_ value: TimeInterval) {
        current.hotkeyToRecordingStart = value
    }

    public func setRecordingStartToSpeechDetected(_ value: TimeInterval) {
        current.recordingStartToSpeechDetected = value
    }

    public func setSpeechEndToFinalASR(_ value: TimeInterval) {
        current.speechEndToFinalASR = value
    }

    public func setFinalASRToCleanup(_ value: TimeInterval) {
        current.finalASRToCleanup = value
    }

    public func setCleanupToPaste(_ value: TimeInterval) {
        current.cleanupToPaste = value
    }

    public func setStopSpeakingToInsertedText(_ value: TimeInterval) {
        current.stopSpeakingToInsertedText = value
    }

    public func setFirstPartialLatency(_ value: TimeInterval) {
        if current.firstPartialLatency == nil {
            current.firstPartialLatency = value
        }
    }

    public func setFirstPartialRequestLatency(_ value: TimeInterval) {
        if current.firstPartialRequestLatency == nil {
            current.firstPartialRequestLatency = value
        }
    }

    public func setFirstPartialASRDuration(_ value: TimeInterval) {
        if current.firstPartialASRDuration == nil {
            current.firstPartialASRDuration = value
        }
    }

    public func setPasteMethod(_ value: String) {
        current.pasteMethod = value
    }

    public func setPastePipelineMetrics(_ metrics: PastePipelineMetrics) {
        current.pasteMethod = metrics.method ?? current.pasteMethod
        current.pasteTargetBehavior = metrics.targetBehavior
        current.pasteTargetAppName = metrics.targetAppName
        current.pasteTargetBundleIdentifier = metrics.targetBundleIdentifier
        current.pasteFocusChanged = metrics.focusChanged
        current.pasteFallbackUsed = metrics.fallbackUsed
        current.pasteFailureReason = metrics.failureReason
        current.clipboardSnapshotDuration = metrics.clipboardSnapshotDuration
        current.clipboardSetDuration = metrics.clipboardSetDuration
        current.targetFocusCheckDuration = metrics.targetFocusCheckDuration
        current.commandVPostDuration = metrics.commandVPostDuration
        current.visibleInsertLatency = metrics.visibleInsertLatency
        current.clipboardRestoreDelay = metrics.clipboardRestoreDelay
        current.clipboardRestoreDuration = metrics.clipboardRestoreDuration
        current.totalPastePipelineDuration = metrics.totalPastePipelineDuration
        current.backgroundClipboardRestoreLatency = metrics.backgroundClipboardRestoreLatency
    }

    public func setUserVisibleStopToInsertLatency(_ value: TimeInterval) {
        current.userVisibleStopToInsertLatency = value
    }

    public func setModelLoadTime(_ value: TimeInterval) {
        current.modelLoadTime = value
    }

    public func setModelWarmupTime(_ value: TimeInterval) {
        current.modelWarmupTime = value
    }

    public func finishCurrent() -> LatencyMetrics {
        let metrics = current
        history.insert(metrics, at: 0)
        current = LatencyMetrics()
        return metrics
    }

    public func latest() -> LatencyMetrics {
        history.first ?? current
    }

    public func all() -> [LatencyMetrics] {
        history
    }
}

public struct Stopwatch: Sendable {
    private let startedAt: ContinuousClock.Instant

    public init(clock: ContinuousClock = ContinuousClock()) {
        self.startedAt = clock.now
    }

    public func elapsedSeconds(clock: ContinuousClock = ContinuousClock()) -> TimeInterval {
        let duration = startedAt.duration(to: clock.now)
        return TimeInterval(duration.components.seconds) + TimeInterval(duration.components.attoseconds) / 1_000_000_000_000_000_000
    }
}
