import AppKit
import ApplicationServices
import Carbon
import Foundation
import LocalVoiceFlowCore

final class HotkeyManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var controlTapStartedAt: CFAbsoluteTime?
    private var controlTapInvalidated = false
    private var lastControlTapEndedAt: CFAbsoluteTime?
    private var holdWorkItem: DispatchWorkItem?
    private var holdStopWorkItem: DispatchWorkItem?
    private var holdState = HoldControlTriggerStateMachine()
    private var triggerMode: TriggerMode = .globalShortcut
    private var holdThreshold: CFTimeInterval = 0.15
    private let holdReleaseGrace: CFTimeInterval = 0.22
    private var doubleTapInterval: CFTimeInterval = 0.32
    private var onToggle: (() -> Void)?
    private var onStart: (() -> Void)?
    private var onStop: (() -> Void)?
    private let maximumControlTapDuration: CFTimeInterval = 0.7

    deinit {
        unregister()
    }

    func register(
        shortcut: GlobalShortcut,
        triggerMode: TriggerMode,
        holdThresholdMilliseconds: Int,
        doubleTapIntervalMilliseconds: Int,
        onToggle: @escaping () -> Void,
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) throws {
        unregister()
        self.triggerMode = triggerMode
        self.holdThreshold = CFTimeInterval(max(80, holdThresholdMilliseconds)) / 1000
        self.doubleTapInterval = CFTimeInterval(max(150, doubleTapIntervalMilliseconds)) / 1000
        self.onToggle = onToggle
        self.onStart = onStart
        self.onStop = onStop

        if triggerMode != .globalShortcut || shortcut.isControlTap {
            try registerControlTap()
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            throw LocalVoiceFlowError.insertionFailed("Unable to install global hotkey handler.")
        }

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("LVFL"), id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode(for: shortcut.key),
            carbonModifiers(for: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            throw LocalVoiceFlowError.insertionFailed("Unable to register \(shortcut.displayName). It may conflict with another app.")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        holdWorkItem?.cancel()
        holdWorkItem = nil
        holdStopWorkItem?.cancel()
        holdStopWorkItem = nil
        holdState.reset()
        controlTapStartedAt = nil
        controlTapInvalidated = false
        lastControlTapEndedAt = nil
    }

    fileprivate func fireToggle() {
        onToggle?()
    }

    private func fireStart() {
        onStart?()
    }

    private func fireStop() {
        onStop?()
    }

    private func registerControlTap() throws {
        let mask: NSEvent.EventTypeMask = [
            .flagsChanged,
            .keyDown,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel
        ]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
            return event
        }

        guard AXIsProcessTrusted() else {
            throw LocalVoiceFlowError.permissionDenied("Grant Accessibility permission to Scrivora so the Control trigger works while another app is focused, then reopen Scrivora or press Refresh in Privacy.")
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
        }

        guard localEventMonitor != nil, globalEventMonitor != nil else {
            throw LocalVoiceFlowError.insertionFailed("Unable to watch the Control trigger in other apps. Grant Accessibility permission to Scrivora, then restart it.")
        }
    }

    private func handleEvent(_ event: NSEvent) {
        let type = event.type
        let keyCode: UInt16
        switch type {
        case .flagsChanged, .keyDown, .keyUp:
            keyCode = event.keyCode
        default:
            keyCode = 0
        }
        let modifierFlags = event.modifierFlags

        if Thread.isMainThread {
            handleEvent(type: type, keyCode: keyCode, modifierFlags: modifierFlags)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleEvent(type: type, keyCode: keyCode, modifierFlags: modifierFlags)
            }
        }
    }

    private func handleEvent(type: NSEvent.EventType, keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(
                keyCode: Int64(keyCode),
                controlIsDown: modifierFlags.contains(.control),
                hasOtherModifiers: hasOtherShortcutModifiers(modifierFlags)
            )
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            if triggerMode == .holdControl {
                performHoldActions(holdState.invalidateCurrentPress())
            } else if controlTapStartedAt != nil {
                controlTapInvalidated = true
                holdWorkItem?.cancel()
            }
        default:
            break
        }
    }

    private func handleFlagsChanged(keyCode: Int64, controlIsDown: Bool, hasOtherModifiers: Bool) {
        guard keyCode == Int64(kVK_Control) || keyCode == Int64(kVK_RightControl) else {
            if controlTapStartedAt != nil {
                controlTapInvalidated = true
            }
            return
        }

        if triggerMode == .holdControl {
            handleHoldControlChanged(controlIsDown: controlIsDown, hasOtherModifiers: hasOtherModifiers)
            return
        }

        if controlIsDown, controlTapStartedAt == nil {
            controlTapStartedAt = CFAbsoluteTimeGetCurrent()
            controlTapInvalidated = hasOtherModifiers
            return
        }

        if !controlIsDown, let startedAt = controlTapStartedAt {
            holdWorkItem?.cancel()
            let duration = CFAbsoluteTimeGetCurrent() - startedAt
            let endedAt = CFAbsoluteTimeGetCurrent()
            let shouldFireTap = !controlTapInvalidated && duration <= maximumControlTapDuration
            controlTapStartedAt = nil
            controlTapInvalidated = false

            if triggerMode == .doubleTapControl, shouldFireTap {
                handleDoubleTap(endedAt: endedAt)
                return
            }

            if triggerMode == .globalShortcut, shouldFireTap {
                DispatchQueue.main.async { [weak self] in self?.fireToggle() }
            }
        }
    }

    private func handleHoldControlChanged(controlIsDown: Bool, hasOtherModifiers: Bool) {
        if controlIsDown {
            performHoldActions(holdState.controlPressed())
            if hasOtherModifiers {
                performHoldActions(holdState.invalidateCurrentPress())
            }
        } else {
            performHoldActions(holdState.controlReleased())
        }
    }

    private func performHoldActions(_ actions: [HoldControlTriggerAction]) {
        for action in actions {
            switch action {
            case .scheduleStartAfterThreshold:
                scheduleHoldStart()
            case .cancelPendingStart:
                holdWorkItem?.cancel()
                holdWorkItem = nil
            case .startRecording:
                DispatchQueue.main.async { [weak self] in self?.fireStart() }
            case .scheduleStopAfterGrace:
                scheduleHoldStopAfterGrace()
            case .cancelPendingStop:
                holdStopWorkItem?.cancel()
                holdStopWorkItem = nil
            case .stopRecording:
                DispatchQueue.main.async { [weak self] in self?.fireStop() }
            }
        }
    }

    private func scheduleHoldStart() {
        holdWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.performHoldActions(self.holdState.holdThresholdElapsed())
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
    }

    private func scheduleHoldStopAfterGrace() {
        holdStopWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.performHoldActions(self.holdState.releaseGraceElapsed())
        }
        holdStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdReleaseGrace, execute: workItem)
    }

    private func handleDoubleTap(endedAt: CFAbsoluteTime) {
        if let lastControlTapEndedAt, endedAt - lastControlTapEndedAt <= doubleTapInterval {
            self.lastControlTapEndedAt = nil
            DispatchQueue.main.async { [weak self] in self?.fireToggle() }
        } else {
            lastControlTapEndedAt = endedAt
        }
    }

    private func hasOtherShortcutModifiers(_ flags: NSEvent.ModifierFlags) -> Bool {
        flags.contains(.command)
            || flags.contains(.option)
            || flags.contains(.shift)
            || flags.contains(.function)
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return noErr }
    let rawPointer = UInt(bitPattern: userData)
    DispatchQueue.main.async {
        guard let pointer = UnsafeRawPointer(bitPattern: rawPointer) else { return }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(pointer).takeUnretainedValue()
        manager.fireToggle()
    }
    return noErr
}

private func carbonModifiers(for modifiers: [ShortcutModifier]) -> UInt32 {
    modifiers.reduce(UInt32(0)) { result, modifier in
        switch modifier {
        case .command:
            result | UInt32(cmdKey)
        case .control:
            result | UInt32(controlKey)
        case .option:
            result | UInt32(optionKey)
        case .shift:
            result | UInt32(shiftKey)
        }
    }
}

private func keyCode(for key: String) -> UInt32 {
    switch key.lowercased() {
    case "space": return UInt32(kVK_Space)
    case "return", "enter": return UInt32(kVK_Return)
    case "escape": return UInt32(kVK_Escape)
    case "0": return UInt32(kVK_ANSI_0)
    case "1": return UInt32(kVK_ANSI_1)
    case "2": return UInt32(kVK_ANSI_2)
    case "3": return UInt32(kVK_ANSI_3)
    case "4": return UInt32(kVK_ANSI_4)
    case "5": return UInt32(kVK_ANSI_5)
    case "6": return UInt32(kVK_ANSI_6)
    case "7": return UInt32(kVK_ANSI_7)
    case "8": return UInt32(kVK_ANSI_8)
    case "9": return UInt32(kVK_ANSI_9)
    default:
        let scalar = key.lowercased().unicodeScalars.first ?? UnicodeScalar(" ")
        switch Character(scalar) {
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        default: return UInt32(kVK_Space)
        }
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value)
    }
    return result
}
