import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class FloatingOverlayController {
    private var panel: NSPanel?

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
        } else {
            panel?.orderFrontRegardless()
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
        }
    }

    private func positionPanel(for appState: AppState) {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = Self.targetSize(for: appState)
        let origin = NSPoint(
            x: visible.midX - (size.width / 2),
            y: visible.minY + 24
        )
        let frame = NSRect(origin: origin, size: size)

        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
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
            case .liquidFlow: return NSSize(width: 74, height: 22)
            case .spectrumBloom: return NSSize(width: 42, height: 32)
            case .minimalSignal: return NSSize(width: 44, height: 20)
            }
        case .finished:
            switch style {
            case .liquidFlow: return NSSize(width: 74, height: 22)
            case .spectrumBloom: return NSSize(width: 42, height: 32)
            case .minimalSignal: return NSSize(width: 44, height: 20)
            }
        case .listening, .speechDetected, .partialTranscription:
            switch style {
            case .liquidFlow: return NSSize(width: 124, height: 44)
            case .spectrumBloom: return NSSize(width: 76, height: 66)
            case .minimalSignal: return NSSize(width: 72, height: 30)
            }
        case .processing:
            switch style {
            case .liquidFlow: return NSSize(width: 92, height: 30)
            case .spectrumBloom: return NSSize(width: 58, height: 52)
            case .minimalSignal: return NSSize(width: 58, height: 24)
            }
        case .failed:
            switch style {
            case .liquidFlow: return NSSize(width: 92, height: 30)
            case .spectrumBloom: return NSSize(width: 58, height: 52)
            case .minimalSignal: return NSSize(width: 58, height: 24)
            }
        }
    }
}
