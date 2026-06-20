import AppKit
import SwiftUI
import LocalVoiceFlowCore

@main
struct LocalVoiceFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup(AppBrand.productName, id: "main") {
            PreferencesRootView()
                .environmentObject(appState)
                .environment(\.colorScheme, .light)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .defaultSize(width: 1180, height: 820)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .environment(\.colorScheme, .light)
        } label: {
            ScrivoraMenuBarLabel(runtimeState: appState.runtimeState)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let initialWindowLaunchKey = "scrivora.launch.presentedInitialWindow.v1"
    private let defaultWindowSize = NSSize(width: 1180, height: 820)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)

        if let iconURL = Bundle.main.url(forResource: "ScrivoraIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }

        let shouldPresentWindow = shouldPresentMainWindowOnLaunch()
        NSApp.setActivationPolicy(shouldPresentWindow ? .regular : .accessory)
        applyLaunchWindowPolicy(shouldPresentWindow: shouldPresentWindow)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.applyLaunchWindowPolicy(shouldPresentWindow: shouldPresentWindow)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        resetPrimaryWindowFrames()

        let windows = primaryWindows()
        if windows.isEmpty {
            return true
        }
        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
        return false
    }

    private func shouldPresentMainWindowOnLaunch() -> Bool {
        if !UserDefaults.standard.bool(forKey: Self.initialWindowLaunchKey) {
            return true
        }

        let settings = (try? SettingsStore(directory: LocalFileStore().settingsDirectory).load()) ?? .default
        return !settings.privacy.firstRunPrivacyChoiceCompleted
    }

    private func applyLaunchWindowPolicy(shouldPresentWindow: Bool) {
        resetPrimaryWindowFrames()
        if shouldPresentWindow {
            UserDefaults.standard.set(true, forKey: Self.initialWindowLaunchKey)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            hidePrimaryWindows()
        }
    }

    private func hidePrimaryWindows() {
        primaryWindows().forEach { $0.orderOut(nil) }
        NSApp.hide(nil)
    }

    private func resetPrimaryWindowFrames() {
        for window in primaryWindows() {
            let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(defaultWindowSize.width, visibleFrame.width)
            let height = min(defaultWindowSize.height, visibleFrame.height)
            let frame = NSRect(
                x: visibleFrame.midX - (width / 2),
                y: visibleFrame.midY - (height / 2),
                width: width,
                height: height
            )
            window.setFrame(frame, display: false)
        }
    }

    private func primaryWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            window.title == AppBrand.productName ||
                window.identifier?.rawValue.contains("main") == true
        }
    }
}
