import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class FloatingOverlayController {
    private var panel: NSPanel?
    private var lastFrame: NSRect?

    func show(appState: AppState) {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.targetSize(for: appState)),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = true
            panel.animationBehavior = .utilityWindow
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.contentView = NSHostingView(rootView: FloatingDictationOverlay().environmentObject(appState))
            self.panel = panel
        }

        positionPanel(for: appState)
        if panel?.isVisible == false {
            panel?.alphaValue = 0
            panel?.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel?.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            self.lastFrame = nil
        }
    }

    private func positionPanel(for appState: AppState) {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = Self.targetSize(for: appState)
        let margin: CGFloat = 24
        let origin: NSPoint
        switch appState.settings.dictation.floatingOverlayPlacement {
        case .bottom:
            origin = NSPoint(
                x: visible.midX - (size.width / 2),
                y: visible.minY + margin
            )
        case .top:
            origin = NSPoint(
                x: visible.midX - (size.width / 2),
                y: visible.maxY - size.height - margin
            )
        case .right:
            origin = NSPoint(
                x: visible.maxX - size.width - margin,
                y: visible.midY - (size.height / 2)
            )
        case .left:
            origin = NSPoint(
                x: visible.minX + margin,
                y: visible.midY - (size.height / 2)
            )
        }
        let frame = NSRect(origin: origin, size: size)
        guard lastFrame != frame else { return }
        lastFrame = frame

        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private static func targetSize(for appState: AppState) -> NSSize {
        let style = appState.settings.dictation.floatingOverlayStyle
        switch appState.runtimeState {
        case .idle:
            switch style {
            case .voiceBars: return NSSize(width: 70, height: 24)
            case .liquidFlow: return NSSize(width: 74, height: 22)
            case .spectrumBloom: return NSSize(width: 42, height: 32)
            case .minimalSignal: return NSSize(width: 44, height: 20)
            case .signalHelix: return NSSize(width: 72, height: 28)
            }
        case .finished:
            switch style {
            case .voiceBars: return NSSize(width: 70, height: 24)
            case .liquidFlow: return NSSize(width: 74, height: 22)
            case .spectrumBloom: return NSSize(width: 42, height: 32)
            case .minimalSignal: return NSSize(width: 44, height: 20)
            case .signalHelix: return NSSize(width: 72, height: 28)
            }
        case .listening, .speechDetected, .partialTranscription:
            switch style {
            case .voiceBars: return NSSize(width: 118, height: 44)
            case .liquidFlow: return NSSize(width: 124, height: 44)
            case .spectrumBloom: return NSSize(width: 76, height: 66)
            case .minimalSignal: return NSSize(width: 72, height: 30)
            case .signalHelix: return NSSize(width: 132, height: 54)
            }
        case .processing:
            switch style {
            case .voiceBars: return NSSize(width: 92, height: 34)
            case .liquidFlow: return NSSize(width: 92, height: 30)
            case .spectrumBloom: return NSSize(width: 58, height: 52)
            case .minimalSignal: return NSSize(width: 58, height: 24)
            case .signalHelix: return NSSize(width: 96, height: 40)
            }
        case .failed:
            switch style {
            case .voiceBars: return NSSize(width: 92, height: 34)
            case .liquidFlow: return NSSize(width: 92, height: 30)
            case .spectrumBloom: return NSSize(width: 58, height: 52)
            case .minimalSignal: return NSSize(width: 58, height: 24)
            case .signalHelix: return NSSize(width: 96, height: 40)
            }
        }
    }
}
