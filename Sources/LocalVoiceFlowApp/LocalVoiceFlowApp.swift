import AppKit
import SwiftUI
import LocalVoiceFlowCore

@main
struct LocalVoiceFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window(AppBrand.productName, id: "main") {
            PreferencesRootView()
                .environmentObject(appState)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .defaultSize(width: 1180, height: 820)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
        } label: {
            Label(AppBrand.productName, systemImage: appState.menuBarSystemImage)
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
