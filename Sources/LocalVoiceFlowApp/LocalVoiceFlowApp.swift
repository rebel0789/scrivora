import AppKit
import SwiftUI
import LocalVoiceFlowCore

@main
struct LocalVoiceFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("LocalVoiceFlow", id: "main") {
            PreferencesRootView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 560)
        }

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
        } label: {
            Label("LocalVoiceFlow", systemImage: appState.menuBarSystemImage)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
