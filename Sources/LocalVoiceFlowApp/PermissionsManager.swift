import AppKit
import ApplicationServices
import AVFoundation
import Foundation

enum PermissionState: String {
    case unknown
    case granted
    case denied

    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .granted: "Granted"
        case .denied: "Denied"
        }
    }
}

struct PermissionsManager {
    func microphonePermissionState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    func requestMicrophonePermission() async -> PermissionState {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .granted : .denied
    }

    func accessibilityPermissionState() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .denied
    }

    func requestAccessibilityPermission() -> PermissionState {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
