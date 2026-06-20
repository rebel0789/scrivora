import Testing
@testable import LocalVoiceFlowCore

struct HotkeyBehaviorTests {
    @Test func globalShortcutProvidesReadableKeyCapLabels() {
        let shortcut = GlobalShortcut(key: "l", modifiers: [.control, .option])

        #expect(shortcut.keyCapLabels == ["Control", "Option", "L"])
    }

    @Test func globalShortcutCanRepresentSingleKeys() {
        #expect(GlobalShortcut(key: "g", modifiers: []).keyCapLabels == ["G"])
        #expect(GlobalShortcut(key: "7", modifiers: []).keyCapLabels == ["7"])
    }

    @Test func holdControlDoesNotAutoStopOnSilenceDuringCapture() {
        var settings = DictationSettings(triggerMode: .holdControl, autoStopOnSilence: true)

        #expect(settings.shouldObserveSilenceAutoStop == false)

        settings.triggerMode = .doubleTapControl
        #expect(settings.shouldObserveSilenceAutoStop == true)

        settings.autoStopOnSilence = false
        #expect(settings.shouldObserveSilenceAutoStop == false)
    }

    @Test func holdControlShortReleaseKeepsOneRecordingSession() {
        var machine = HoldControlTriggerStateMachine()

        #expect(machine.controlPressed() == [.scheduleStartAfterThreshold])
        #expect(machine.holdThresholdElapsed() == [.startRecording])
        #expect(machine.controlReleased() == [.cancelPendingStart, .scheduleStopAfterGrace])

        #expect(machine.controlPressed() == [.cancelPendingStop])
        #expect(machine.holdThresholdElapsed() == [])

        #expect(machine.controlReleased() == [.cancelPendingStart, .scheduleStopAfterGrace])
        #expect(machine.releaseGraceElapsed() == [.stopRecording])
    }

    @Test func holdControlReleaseGraceFiresStopOnlyOnce() {
        var machine = HoldControlTriggerStateMachine()

        _ = machine.controlPressed()
        _ = machine.holdThresholdElapsed()
        _ = machine.controlReleased()

        #expect(machine.releaseGraceElapsed() == [.stopRecording])
        #expect(machine.releaseGraceElapsed() == [])
    }

    @Test func holdControlInvalidatedPressDoesNotStartOrStop() {
        var machine = HoldControlTriggerStateMachine()

        #expect(machine.controlPressed() == [.scheduleStartAfterThreshold])
        #expect(machine.invalidateCurrentPress() == [.cancelPendingStart])
        #expect(machine.holdThresholdElapsed() == [])
        #expect(machine.controlReleased() == [.cancelPendingStart])
        #expect(machine.releaseGraceElapsed() == [])
    }
}
