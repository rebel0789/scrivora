import AppKit
import ApplicationServices
import Foundation
import LocalVoiceFlowCore

enum TextInsertionMethod: String {
    case copiedOnly
    case clipboardPaste
}

struct TextInsertionResult {
    var method: TextInsertionMethod
    var restoredClipboard: Bool
    var metrics: PastePipelineMetrics
}

@MainActor
final class TextInsertionService {
    func insertText(
        _ text: String,
        startApplication: NSRunningApplication?,
        endApplication: NSRunningApplication?,
        autoPaste: Bool,
        pasteTargetBehavior: PasteTargetBehavior,
        pasteStrategy: PasteStrategy,
        customRestoreDelayMilliseconds: Int
    ) async throws -> TextInsertionResult {
        let pipelineWatch = Stopwatch()
        var metrics = PastePipelineMetrics(
            targetBehavior: pasteTargetBehavior.rawValue,
            targetAppName: targetApplication(
                startApplication: startApplication,
                endApplication: endApplication,
                behavior: pasteTargetBehavior
            )?.localizedName,
            targetBundleIdentifier: targetApplication(
                startApplication: startApplication,
                endApplication: endApplication,
                behavior: pasteTargetBehavior
            )?.bundleIdentifier
        )

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            metrics.method = TextInsertionMethod.copiedOnly.rawValue
            metrics.fallbackUsed = true
            metrics.totalPastePipelineDuration = pipelineWatch.elapsedSeconds()
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false, metrics: metrics)
        }

        let snapshotWatch = Stopwatch()
        let snapshot = ClipboardSnapshot.capture()
        metrics.clipboardSnapshotDuration = snapshotWatch.elapsedSeconds()

        let setWatch = Stopwatch()
        copyToClipboard(text)
        metrics.clipboardSetDuration = setWatch.elapsedSeconds()

        guard autoPaste, pasteTargetBehavior != .copyOnly, pasteStrategy != .copyOnly else {
            metrics.method = TextInsertionMethod.copiedOnly.rawValue
            metrics.fallbackUsed = true
            metrics.totalPastePipelineDuration = pipelineWatch.elapsedSeconds()
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false, metrics: metrics)
        }

        let target = targetApplication(
            startApplication: startApplication,
            endApplication: endApplication,
            behavior: pasteTargetBehavior
        )
        guard let target else {
            metrics.method = TextInsertionMethod.copiedOnly.rawValue
            metrics.fallbackUsed = true
            metrics.failureReason = "noPasteTarget"
            metrics.totalPastePipelineDuration = pipelineWatch.elapsedSeconds()
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false, metrics: metrics)
        }

        let focusWatch = Stopwatch()
        let frontmost = NSWorkspace.shared.frontmostApplication
        let focusMatches = frontmost?.processIdentifier == target.processIdentifier
        metrics.targetFocusCheckDuration = focusWatch.elapsedSeconds()
        metrics.focusChanged = !focusMatches

        guard focusMatches else {
            metrics.method = TextInsertionMethod.copiedOnly.rawValue
            metrics.fallbackUsed = true
            let expected = target.localizedName ?? "original target"
            let actual = frontmost?.localizedName ?? "no frontmost app"
            metrics.failureReason = "targetFocusChanged expected=\(expected) actual=\(actual)"
            metrics.totalPastePipelineDuration = pipelineWatch.elapsedSeconds()
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false, metrics: metrics)
        }

        let accessibilityTrusted = AXIsProcessTrusted()
        guard accessibilityTrusted else {
            metrics.method = TextInsertionMethod.copiedOnly.rawValue
            metrics.fallbackUsed = true
            metrics.failureReason = "accessibilityPermissionRequired"
            metrics.totalPastePipelineDuration = pipelineWatch.elapsedSeconds()
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false, metrics: metrics)
        }

        let commandWatch = Stopwatch()
        sendCommandV()
        metrics.commandVPostDuration = commandWatch.elapsedSeconds()
        metrics.visibleInsertLatency = pipelineWatch.elapsedSeconds()
        metrics.method = TextInsertionMethod.clipboardPaste.rawValue

        var restored = false
        if let delay = pasteStrategy.restoreDelayMilliseconds(customDelay: customRestoreDelayMilliseconds),
           let snapshot {
            metrics.clipboardRestoreDelay = TimeInterval(delay) / 1_000
            try await Task.sleep(for: .milliseconds(delay))
            let restoreWatch = Stopwatch()
            snapshot.restore()
            metrics.clipboardRestoreDuration = restoreWatch.elapsedSeconds()
            metrics.backgroundClipboardRestoreLatency = metrics.visibleInsertLatency.map {
                pipelineWatch.elapsedSeconds() - $0
            }
            restored = true
        }
        metrics.totalPastePipelineDuration = pipelineWatch.elapsedSeconds()

        return TextInsertionResult(method: .clipboardPaste, restoredClipboard: restored, metrics: metrics)
    }

    private func targetApplication(
        startApplication: NSRunningApplication?,
        endApplication: NSRunningApplication?,
        behavior: PasteTargetBehavior
    ) -> NSRunningApplication? {
        switch behavior {
        case .focusedAtStart:
            return startApplication
        case .focusedAtEnd:
            return endApplication
        case .copyOnly:
            return nil
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private struct ClipboardSnapshot {
    var items: [NSPasteboardItem]

    static func capture() -> ClipboardSnapshot? {
        let pasteboard = NSPasteboard.general
        guard let existingItems = pasteboard.pasteboardItems, !existingItems.isEmpty else {
            return nil
        }

        let copies = existingItems.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }

        return ClipboardSnapshot(items: copies)
    }

    func restore() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}
