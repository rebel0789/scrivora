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

@MainActor
final class TextInsertionService {
    func insertText(
        _ text: String,
        targetApplication: NSRunningApplication?,
        autoPaste: Bool,
        restoreClipboard: Bool
    ) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        copyToClipboard(text)

        if autoPaste, let targetApplication, targetApplication.processIdentifier != NSRunningApplication.current.processIdentifier {
            targetApplication.activate(options: [.activateIgnoringOtherApps])
            try await Task.sleep(for: .milliseconds(180))
        }

        let accessibilityTrusted = AXIsProcessTrusted()
        guard autoPaste else {
            return
        }

        guard accessibilityTrusted else {
            throw TextInsertionError.accessibilityPermissionRequired
        }

        sendCommandV()

        // Keep the transcript on the clipboard even when auto-paste is enabled.
        // This guarantees a manual Cmd+V fallback when the focused app rejects synthetic paste.
        _ = restoreClipboard
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
