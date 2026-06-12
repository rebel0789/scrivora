import AppKit
import ApplicationServices
import Foundation

private enum TextInsertionError: LocalizedError {
    case accessibilityPermissionRequired

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required to paste into the focused app. The transcript was copied to the clipboard."
        }
    }
}

enum TextInsertionMethod: String {
    case copiedOnly
    case clipboardPaste
}

struct TextInsertionResult {
    var method: TextInsertionMethod
    var restoredClipboard: Bool
}

@MainActor
final class TextInsertionService {
    func insertText(
        _ text: String,
        targetApplication: NSRunningApplication?,
        autoPaste: Bool,
        restoreClipboard: Bool,
        restoreDelayMilliseconds: Int
    ) async throws -> TextInsertionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false)
        }
        let snapshot = ClipboardSnapshot.capture()
        copyToClipboard(text)

        if autoPaste, let targetApplication, targetApplication.processIdentifier != NSRunningApplication.current.processIdentifier {
            targetApplication.activate(options: [.activateIgnoringOtherApps])
            try await Task.sleep(for: .milliseconds(180))
        }

        let accessibilityTrusted = AXIsProcessTrusted()
        guard autoPaste else {
            return TextInsertionResult(method: .copiedOnly, restoredClipboard: false)
        }

        guard accessibilityTrusted else {
            throw TextInsertionError.accessibilityPermissionRequired
        }

        sendCommandV()
        var restored = false
        if restoreClipboard, let snapshot {
            let delay = max(0, restoreDelayMilliseconds)
            try await Task.sleep(for: .milliseconds(delay))
            snapshot.restore()
            restored = true
        }

        return TextInsertionResult(method: .clipboardPaste, restoredClipboard: restored)
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
