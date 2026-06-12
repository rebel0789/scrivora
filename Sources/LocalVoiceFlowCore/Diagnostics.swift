import Foundation

public struct LatencyMetrics: Codable, Equatable, Sendable {
    public var hotkeyToRecordingStart: TimeInterval?
    public var recordingStartToSpeechDetected: TimeInterval?
    public var speechEndToFinalASR: TimeInterval?
    public var finalASRToCleanup: TimeInterval?
    public var cleanupToPaste: TimeInterval?
    public var stopSpeakingToInsertedText: TimeInterval?
    public var firstPartialLatency: TimeInterval?
    public var pasteMethod: String?
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
        pasteMethod: String? = nil,
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
        self.pasteMethod = pasteMethod
        self.modelLoadTime = modelLoadTime
        self.modelWarmupTime = modelWarmupTime
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

    public func setPasteMethod(_ value: String) {
        current.pasteMethod = value
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
