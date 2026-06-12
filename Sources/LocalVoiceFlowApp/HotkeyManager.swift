import Carbon
import CoreGraphics
import Foundation
import LocalVoiceFlowCore

final class HotkeyManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var controlTapStartedAt: CFAbsoluteTime?
    private var controlTapInvalidated = false
    private var controlHoldActivated = false
    private var lastControlTapEndedAt: CFAbsoluteTime?
    private var holdWorkItem: DispatchWorkItem?
    private var triggerMode: TriggerMode = .globalShortcut
    private var holdThreshold: CFTimeInterval = 0.15
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
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
            self.eventTapRunLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        holdWorkItem?.cancel()
        holdWorkItem = nil
        controlTapStartedAt = nil
        controlTapInvalidated = false
        controlHoldActivated = false
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

    fileprivate func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            if controlTapStartedAt != nil {
                controlTapInvalidated = true
                holdWorkItem?.cancel()
            }
        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func registerControlTap() throws {
        let eventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: controlTapEventHandler,
            userInfo: selfPointer
        ) else {
            throw LocalVoiceFlowError.insertionFailed("Unable to register Control trigger. Grant Accessibility permission and restart Scrivora.")
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CGEvent.tapEnable(tap: tap, enable: false)
            throw LocalVoiceFlowError.insertionFailed("Unable to create Control Tap run loop source.")
        }

        eventTap = tap
        eventTapRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_Control) || keyCode == Int64(kVK_RightControl) else {
            if controlTapStartedAt != nil {
                controlTapInvalidated = true
            }
            return
        }

        let flags = event.flags
        let controlIsDown = flags.contains(.maskControl)

        if controlIsDown, controlTapStartedAt == nil {
            controlTapStartedAt = CFAbsoluteTimeGetCurrent()
            controlTapInvalidated = hasOtherShortcutModifiers(flags)
            controlHoldActivated = false
            scheduleHoldStartIfNeeded(startedAt: controlTapStartedAt)
            return
        }

        if !controlIsDown, let startedAt = controlTapStartedAt {
            holdWorkItem?.cancel()
            let duration = CFAbsoluteTimeGetCurrent() - startedAt
            let endedAt = CFAbsoluteTimeGetCurrent()
            let shouldFireTap = !controlTapInvalidated && duration <= maximumControlTapDuration
            let shouldStopHold = triggerMode == .holdControl && controlHoldActivated
            controlTapStartedAt = nil
            controlTapInvalidated = false
            controlHoldActivated = false

            if shouldStopHold {
                DispatchQueue.main.async { [weak self] in self?.fireStop() }
                return
            }

            if triggerMode == .doubleTapControl, shouldFireTap {
                handleDoubleTap(endedAt: endedAt)
                return
            }

            if triggerMode == .globalShortcut, shouldFireTap {
                DispatchQueue.main.async { [weak self] in self?.fireToggle() }
            }
        }
    }

    private func scheduleHoldStartIfNeeded(startedAt: CFAbsoluteTime?) {
        guard triggerMode == .holdControl, let startedAt else { return }
        holdWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.triggerMode == .holdControl,
                  self.controlTapStartedAt == startedAt,
                  !self.controlTapInvalidated,
                  !self.controlHoldActivated
            else { return }

            self.controlHoldActivated = true
            self.fireStart()
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
    }

    private func handleDoubleTap(endedAt: CFAbsoluteTime) {
        if let lastControlTapEndedAt, endedAt - lastControlTapEndedAt <= doubleTapInterval {
            self.lastControlTapEndedAt = nil
            DispatchQueue.main.async { [weak self] in self?.fireToggle() }
        } else {
            lastControlTapEndedAt = endedAt
        }
    }

    private func hasOtherShortcutModifiers(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand)
            || flags.contains(.maskAlternate)
            || flags.contains(.maskShift)
            || flags.contains(.maskSecondaryFn)
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

private let controlTapEventHandler: CGEventTapCallBack = { proxy, type, event, userData in
    guard let userData else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    return manager.handleEventTap(proxy: proxy, type: type, event: event)
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
