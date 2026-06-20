public enum HoldControlTriggerAction: Equatable, Sendable {
    case scheduleStartAfterThreshold
    case cancelPendingStart
    case startRecording
    case scheduleStopAfterGrace
    case cancelPendingStop
    case stopRecording
}

public struct HoldControlTriggerStateMachine: Sendable {
    private var controlIsPressed = false
    private var pressIsValid = false
    private var recordingIsActive = false
    private var stopIsPending = false

    public init() {}

    public mutating func controlPressed() -> [HoldControlTriggerAction] {
        controlIsPressed = true
        pressIsValid = true

        if stopIsPending {
            stopIsPending = false
            return [.cancelPendingStop]
        }

        guard !recordingIsActive else {
            return []
        }

        return [.scheduleStartAfterThreshold]
    }

    public mutating func holdThresholdElapsed() -> [HoldControlTriggerAction] {
        guard controlIsPressed, pressIsValid, !recordingIsActive else {
            return []
        }

        recordingIsActive = true
        return [.startRecording]
    }

    public mutating func controlReleased() -> [HoldControlTriggerAction] {
        controlIsPressed = false
        pressIsValid = false

        guard recordingIsActive else {
            return [.cancelPendingStart]
        }

        stopIsPending = true
        return [.cancelPendingStart, .scheduleStopAfterGrace]
    }

    public mutating func releaseGraceElapsed() -> [HoldControlTriggerAction] {
        guard stopIsPending, recordingIsActive, !controlIsPressed else {
            return []
        }

        stopIsPending = false
        recordingIsActive = false
        return [.stopRecording]
    }

    public mutating func invalidateCurrentPress() -> [HoldControlTriggerAction] {
        guard controlIsPressed else {
            return []
        }

        pressIsValid = false
        return recordingIsActive ? [] : [.cancelPendingStart]
    }

    public mutating func reset() {
        controlIsPressed = false
        pressIsValid = false
        recordingIsActive = false
        stopIsPending = false
    }
}
