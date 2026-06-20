import AppKit
import Carbon
import SwiftUI
import LocalVoiceFlowCore

private enum MainSection: String, CaseIterable, Identifiable {
    case dashboard
    case dictation
    case models
    case cleanup
    case history
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Home"
        case .dictation: "Controls"
        case .models: "Models"
        case .cleanup: "Writing"
        case .history: "History"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "house.fill"
        case .dictation: "keyboard"
        case .models: "cube.transparent"
        case .cleanup: "slider.horizontal.3"
        case .history: "doc.text"
        case .privacy: "lock.shield.fill"
        case .about: "info.circle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: "Dictate and copy"
        case .dictation: "Shortcut and indicator"
        case .models: "Local speech models"
        case .cleanup: "Writing style"
        case .history: "Recent dictations"
        case .privacy: "Permissions and data"
        case .about: "Version and updates"
        }
    }

    static let core: [MainSection] = [.dashboard, .dictation, .models]
    static let intelligence: [MainSection] = [.cleanup, .history]
    static let system: [MainSection] = [.privacy, .about]
}

private extension Notification.Name {
    static let scrivoraMainSectionRequested = Notification.Name("me.scrivora.mainSectionRequested")
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                appState.toggleDictation()
            } label: {
                Label(dictationButtonTitle, systemImage: appState.menuBarSystemImage)
            }

            Text(appState.runtimeState.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = appState.lastError {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
            }

            Divider()
            Button {
                copyLastTranscript()
            } label: {
                Label("Copy Latest Text", systemImage: "doc.on.doc")
            }
            .disabled(latestTranscript.isEmpty)

            Button {
                openSection(.history)
            } label: {
                Label("Open History", systemImage: "clock.arrow.circlepath")
            }

            Divider()
            Menu {
                if let selected = appState.selectedModel {
                    Text("\(selected.backend.rawValue) - \(selected.mode.displayLabel)")
                        .foregroundStyle(.secondary)
                    Divider()
                }

                if downloadedModels.isEmpty {
                    Text("No downloaded models")
                } else {
                    ForEach(downloadedModels) { model in
                        Button {
                            appState.selectModel(model)
                        } label: {
                            Label(
                                model.displayName,
                                systemImage: model.id == appState.selectedModel?.id
                                    ? "checkmark.circle.fill"
                                    : model.menuSystemImage
                            )
                        }
                    }
                }

                Divider()
                Button {
                    openSection(.models)
                } label: {
                    Label("Manage Models", systemImage: "cube.transparent")
                }
            } label: {
                Label(appState.selectedModel?.displayName ?? "Model", systemImage: "waveform.badge.magnifyingglass")
            }

            Divider()
            Button {
                openSection(.dashboard)
            } label: {
                Label("Home", systemImage: "house")
            }
            Button {
                openSection(.dictation)
            } label: {
                Label("Controls", systemImage: "keyboard")
            }
            Button {
                openSection(.cleanup)
            } label: {
                Label("Writing", systemImage: "slider.horizontal.3")
            }
            Button {
                openSection(.privacy)
            } label: {
                Label("Privacy", systemImage: "lock.shield")
            }

            Divider()
            Button {
                Task { await appState.checkForUpdates(manual: true) }
                openSection(.about)
            } label: {
                Label(appState.isCheckingForUpdates ? "Checking Updates" : "Check for Updates", systemImage: "arrow.clockwise")
            }
            .disabled(appState.isCheckingForUpdates)

            Toggle("Privacy Mode", isOn: Binding(
                get: { appState.settings.privacy.privacyMode },
                set: { appState.setPrivacyMode($0) }
            ))
            Button {
                openSection(.dashboard)
            } label: {
                Label("Open \(AppBrand.productName)", systemImage: "macwindow")
            }
            Button {
                appState.openDataFolder()
            } label: {
                Label("Open Data", systemImage: "folder")
            }
            Divider()
            Button("Quit \(AppBrand.productName)") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 280)
    }

    private var latestTranscript: String {
        if let latestHistoryTranscript = appState.history.first?.finalTranscript,
           !latestHistoryTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return latestHistoryTranscript
        }
        let final = appState.finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty {
            return appState.finalTranscript
        }
        return ""
    }

    private var downloadedModels: [ASRModelInfo] {
        appState.modelCatalog.models
            .filter { appState.isModelDownloaded($0) }
            .filter { $0.backend == .fluidAudio || $0.backend == .whisperCpp }
    }

    private func copyLastTranscript() {
        guard !latestTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(latestTranscript, forType: .string)
    }

    private func openSection(_ section: MainSection) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        postOpenSection(section)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            postOpenSection(section)
        }
    }

    private func postOpenSection(_ section: MainSection) {
        NotificationCenter.default.post(name: .scrivoraMainSectionRequested, object: section.rawValue)
    }

    private var dictationButtonTitle: String {
        switch appState.runtimeState {
        case .listening, .speechDetected, .partialTranscription:
            "Stop Dictation"
        default:
            "Start Dictation"
        }
    }
}

struct PreferencesRootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("scrivora.sidebar.compact") private var isSidebarCompact = false
    @State private var selection: MainSection? = .dashboard
    @State private var detailResetID = UUID()
    @State private var hiddenUpdateVersion: String?

    var body: some View {
        if appState.needsFirstRunPrivacyChoice {
            PrivacyOnboardingView()
                .frame(minWidth: 1080, minHeight: 720)
        } else {
            mainPreferences
        }
    }

    private var mainPreferences: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    SidebarHeader(isCompact: $isSidebarCompact)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            SidebarNavigationGroup(title: nil, sections: MainSection.core, selection: sidebarSelection, isCompact: isSidebarCompact)
                            SidebarNavigationGroup(title: nil, sections: MainSection.intelligence, selection: sidebarSelection, isCompact: isSidebarCompact)
                        }
                        .padding(.horizontal, isSidebarCompact ? 8 : 12)
                        .padding(.top, 6)
                        .padding(.bottom, 18)
                    }
                    .scrollIndicators(.hidden)

                    Spacer(minLength: 0)

                    SidebarNavigationGroup(title: nil, sections: MainSection.system, selection: sidebarSelection, isCompact: isSidebarCompact)
                        .padding(.horizontal, isSidebarCompact ? 8 : 12)
                        .padding(.bottom, 12)

                    Spacer(minLength: 10)
                }
                .background(SidebarSurface())
                .frame(width: sidebarWidth)
                .clipped()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        detailView
                    }
                    .padding(.horizontal, detailHorizontalPadding(for: geometry.size.width))
                    .padding(.top, 58)
                    .padding(.bottom, 36)
                    .frame(maxWidth: detailMaxWidth(for: geometry.size.width), alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .id(detailResetID)
                .scrollContentBackground(.hidden)
                .background(AppCanvasBackground())
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSidebarCompact)
        }
        .toolbar {
            ToolbarItemGroup {
                if let selectedModel = appState.selectedModel {
                    ToolbarModelChip(
                        value: selectedModel.displayName
                    )
                }
                Button {
                    appState.toggleDictation()
                } label: {
                    Label(dictationButtonTitle, systemImage: appState.menuBarSystemImage)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        .tint(BrandColor.terracotta)
        .frame(minWidth: 1080, minHeight: 720)
        .overlay {
            if shouldPresentUpdateDialog, let update = appState.availableUpdate {
                UpdateAvailableOverlay(
                    update: update,
                    currentVersion: appState.appVersion,
                    statusMessage: appState.updateStatusMessage,
                    isInstalling: appState.isInstallingUpdate,
                    onCancel: { hiddenUpdateVersion = update.version },
                    onSkipVersion: {
                        hiddenUpdateVersion = update.version
                        appState.dismissUpdateAnnouncement()
                    },
                    onReleaseNotes: appState.openAvailableUpdateReleaseNotes,
                    onInstall: appState.installAvailableUpdate
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: shouldPresentUpdateDialog)
        .onReceive(NotificationCenter.default.publisher(for: .scrivoraMainSectionRequested)) { notification in
            guard let rawValue = notification.object as? String,
                  let section = MainSection(rawValue: rawValue) else {
                return
            }
            selection = section
            detailResetID = UUID()
        }
    }

    private var sidebarWidth: CGFloat {
        isSidebarCompact ? 78 : 252
    }

    private func detailHorizontalPadding(for windowWidth: CGFloat) -> CGFloat {
        if windowWidth >= 1_500 {
            return 64
        }
        if windowWidth <= 1_150 {
            return 30
        }
        return 46
    }

    private func detailMaxWidth(for windowWidth: CGFloat) -> CGFloat {
        let availableWidth = max(0, windowWidth - sidebarWidth)
        let paddedContentWidth = availableWidth - (detailHorizontalPadding(for: windowWidth) * 2)
        return min(max(paddedContentWidth, 980), 1_360)
    }

    private var sidebarSelection: Binding<MainSection?> {
        Binding(
            get: { selection },
            set: { newSelection in
                selection = newSelection
                detailResetID = UUID()
            }
        )
    }

    @ViewBuilder private var detailView: some View {
        switch selection ?? .dashboard {
        case .dashboard:
            DashboardView()
        case .dictation:
            DictationSettingsView()
        case .models:
            ModelManagerView()
        case .cleanup:
            PostProcessingSettingsView()
        case .history:
            HistoryView()
        case .privacy:
            PrivacyView()
        case .about:
            AboutView()
        }
    }

    private var shouldPresentUpdateDialog: Bool {
        guard appState.shouldShowUpdateAnnouncement, let update = appState.availableUpdate else {
            return false
        }
        return hiddenUpdateVersion != update.version
    }

    private var dictationButtonTitle: String {
        switch appState.runtimeState {
        case .listening, .speechDetected, .partialTranscription:
            "Stop"
        default:
            "Dictate"
        }
    }

}

private struct PrivacyOnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Choose Privacy",
                    subtitle: "Pick what Scrivora may save locally on this Mac.",
                    systemImage: "lock.shield.fill",
                    accent: BrandColor.mutedSage
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    PrivacyChoiceCard(
                        profile: .maximumPrivacy,
                        title: "Maximum Privacy",
                        detail: "No transcript history, no learning memory, no target app names in logs.",
                        systemImage: "lock.fill"
                    )
                    PrivacyChoiceCard(
                        profile: .balancedLocalMemory,
                        title: "Balanced Local Memory",
                        detail: "Saves transcript history and corrections locally so cleanup can improve.",
                        systemImage: "sparkles"
                    )
                }

                Panel("Permission Use") {
                    Text("Scrivora needs Accessibility permission only to detect your dictation trigger and paste the final text into the app you are using. Your audio is transcribed locally.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
            .frame(maxWidth: 980, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct PrivacyChoiceCard: View {
    @EnvironmentObject private var appState: AppState
    var profile: PrivacyProfile
    var title: String
    var detail: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(profile == .maximumPrivacy ? BrandColor.mutedSage : BrandColor.terracotta)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                appState.applyPrivacyChoice(profile)
            } label: {
                Label(profile == .maximumPrivacy ? "Use Default" : "Use \(profile.displayName)", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct SidebarNavigationGroup: View {
    var title: String?
    var sections: [MainSection]
    @Binding var selection: MainSection?
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title, !isCompact {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.45))
                        .frame(height: 1)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }

            ForEach(sections) { section in
                SidebarRow(section: section, isSelected: selection == section, isCompact: isCompact)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = section
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(section.title)
                    .accessibilityAction {
                        selection = section
                    }
            }
        }
    }
}

private struct SidebarHeader: View {
    @Binding var isCompact: Bool

    var body: some View {
        VStack(alignment: isCompact ? .center : .leading, spacing: isCompact ? 12 : 14) {
            HStack(spacing: 12) {
                ScrivoraAppIconMark()
                    .frame(width: isCompact ? 34 : 40, height: isCompact ? 34 : 40)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            isCompact.toggle()
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(isCompact ? "Expand sidebar" : "Collapse sidebar")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            isCompact.toggle()
                        }
                    }
                .help(isCompact ? "Expand sidebar" : "Collapse sidebar")

                if !isCompact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppBrand.productName)
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                        Text("Private Mac dictation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))

                    Spacer(minLength: 0)
                        .transition(.opacity)

                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                isCompact = true
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Collapse sidebar")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                isCompact = true
                            }
                        }
                        .help("Collapse sidebar")
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isCompact)
        }
        .padding(.horizontal, isCompact ? 8 : 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

private struct SidebarRow: View {
    var section: MainSection
    var isSelected: Bool
    var isCompact = false
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            if isCompact {
                Spacer(minLength: 0)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconBackground)
                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? BrandColor.terracottaDeep : .secondary)
            }
            .frame(width: 27, height: 27)

            if !isCompact {
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? BrandColor.charcoal : .primary)
                        .lineLimit(1)
                    Text(section.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, isCompact ? 5 : 9)
        .padding(.vertical, isCompact ? 7 : 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? BrandColor.terracotta : Color.clear)
                    .frame(width: 3)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.leading, 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? BrandColor.terracotta.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .help(section.title)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: isCompact)
    }

    private var rowBackground: Color {
        if isSelected {
            return BrandColor.terracotta.opacity(0.14)
        }
        if isHovering {
            return Color.primary.opacity(0.055)
        }
        return .clear
    }

    private var iconBackground: Color {
        if isSelected {
            return BrandColor.terracotta.opacity(0.16)
        }
        if isHovering {
            return Color.primary.opacity(0.06)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.65)
    }
}
private struct SidebarSurface: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.bar)
            BrandColor.warmSand
                .opacity(0.36)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                BrandColor.terracotta.opacity(0.16),
                                BrandColor.mutedSage.opacity(0.08),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 180)
                Spacer(minLength: 0)
            }
            HStack {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(width: 1)
            }
        }
    }
}

private struct AppCanvasBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            BrandColor.warmSand
                .opacity(0.20)
        }
        .ignoresSafeArea()
    }
}

private struct ToolbarModelChip: View {
    var value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct PageHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)
        }
        .padding(.bottom, 2)
    }
}

private struct Panel<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 8, y: 3)
        .controlSize(.large)
    }
}

private struct StatusPill: View {
    var label: String
    var color: Color

    init(_ label: String, color: Color) {
        self.label = label
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(color.opacity(0.13), in: Capsule())
        .foregroundStyle(color)
    }
}

private struct InfoRow: View {
    var title: String
    var value: String
    var color: Color?

    init(_ title: String, _ value: String, color: Color? = nil) {
        self.title = title
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer(minLength: 18)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(color ?? .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.body)
        .padding(.vertical, 3)
    }
}

private struct SettingsLine<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer(minLength: 20)
            content
                .frame(maxWidth: 380, alignment: .trailing)
        }
        .font(.body)
        .padding(.vertical, 4)
    }
}

private struct SettingControlRow<Control: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    @ViewBuilder var control: Control

    init(
        _ title: String,
        subtitle: String,
        systemImage: String,
        tint: Color = BrandColor.terracotta,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)

            control
                .frame(maxWidth: 360, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

private struct SettingToggleRow: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color = BrandColor.terracotta
    @Binding var isOn: Bool

    var body: some View {
        SettingControlRow(title, subtitle: subtitle, systemImage: systemImage, tint: tint) {
            SwitchPill(isOn: $isOn, tint: tint)
        }
    }
}

private struct SwitchPill: View {
    @Binding var isOn: Bool
    var tint: Color

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.primary : Color(nsColor: .tertiaryLabelColor).opacity(0.32))
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    .padding(3)
            }
            .frame(width: 48, height: 28)
            .overlay(
                Capsule()
                    .stroke(isOn ? tint.opacity(0.20) : Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct KeySequence: View {
    var keys: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                if index > 0 {
                    Text("+")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                KeyCap(key)
            }
        }
    }
}

private struct ShortcutModeRow: View {
    var title: String
    var subtitle: String
    var keys: [String]
    var isActive: Bool
    var systemImage: String
    var editAction: (() -> Void)? = nil
    var action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    if isActive {
                        StatusPill("Active", color: BrandColor.mutedSage)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)

            HStack(spacing: 14) {
                KeySequence(keys: keys)
                    .frame(minWidth: 154, alignment: .trailing)
                if let editAction {
                    Button {
                        editAction()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .help("Record shortcut")
                    .accessibilityLabel("Record shortcut")
                }
                Button {
                    action()
                } label: {
                    Label(isActive ? "On" : "Use", systemImage: isActive ? "checkmark.circle.fill" : systemImage)
                        .frame(minWidth: 78)
                }
                .buttonStyle(.bordered)
                .disabled(isActive)
            }
        }
        .padding(16)
        .background(isActive ? BrandColor.terracotta.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? BrandColor.terracotta.opacity(0.30) : Color(nsColor: .separatorColor).opacity(0.24), lineWidth: 1)
        )
    }
}

private struct ShortcutRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    var currentShortcut: GlobalShortcut
    var onSave: (GlobalShortcut) -> Void

    @State private var capturedShortcut: GlobalShortcut?
    @State private var eventMonitor: Any?
    @State private var message = "Press and hold the key combination you want to use"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Record Shortcut")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Close")
            }
            .padding(20)

            Divider()

            VStack(spacing: 18) {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                        )

                    if let capturedShortcut {
                        KeySequence(keys: capturedShortcut.keyCapLabels)
                    } else {
                        Text("Press a key or key combination...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 88)
            }
            .padding(20)

            Divider()

            HStack {
                Button("Clear") {
                    capturedShortcut = nil
                    message = "Press the key or key combination you want to use"
                }
                .disabled(capturedShortcut == nil)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Shortcut") {
                    guard let capturedShortcut else { return }
                    onSave(capturedShortcut)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandColor.terracotta)
                .disabled(capturedShortcut == nil)
            }
            .padding(20)
        }
        .frame(width: 500)
        .onAppear {
            capturedShortcut = currentShortcut.isControlTap ? nil : currentShortcut
            startMonitoring()
        }
        .onDisappear {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        stopMonitoring()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if let shortcut = shortcut(from: event) {
                capturedShortcut = shortcut
                message = "Shortcut captured. Save it or press another key."
                return nil
            }
            return nil
        }
    }

    private func stopMonitoring() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func shortcut(from event: NSEvent) -> GlobalShortcut? {
        let modifiers = shortcutModifiers(from: event.modifierFlags)
        guard let key = normalizedKey(from: event) else {
            message = "That key is not supported yet. Use a letter, number, Space, Return, or Escape."
            return nil
        }
        return GlobalShortcut(key: key, modifiers: modifiers)
    }

    private func shortcutModifiers(from flags: NSEvent.ModifierFlags) -> [ShortcutModifier] {
        var modifiers: [ShortcutModifier] = []
        if flags.contains(.command) { modifiers.append(.command) }
        if flags.contains(.control) { modifiers.append(.control) }
        if flags.contains(.option) { modifiers.append(.option) }
        if flags.contains(.shift) { modifiers.append(.shift) }
        return modifiers
    }

    private func normalizedKey(from event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Space:
            return "space"
        case kVK_Return:
            return "return"
        case kVK_Escape:
            return "escape"
        default:
            guard let character = event.charactersIgnoringModifiers?.lowercased().first,
                  (("a"..."z").contains(String(character)) || ("0"..."9").contains(String(character)))
            else {
                return nil
            }
            return String(character)
        }
    }
}

struct FloatingDictationOverlay: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VoiceFlowHUD(
            mode: visualMode,
            style: appState.settings.dictation.floatingOverlayStyle,
            palette: appState.settings.dictation.floatingOverlayPalette,
            level: appState.voiceLevel,
            brightness: appState.voiceBrightness,
            spectrum: appState.voiceSpectrum,
            reduceMotion: reduceMotion
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(visualMode.accessibilityLabel)
    }

    private var visualMode: FloatingOverlayMode {
        switch appState.runtimeState {
        case .idle, .finished:
            .idle
        case .listening, .speechDetected, .partialTranscription:
            .recording
        case .processing:
            .processing
        case .failed:
            .failed
        }
    }
}

private enum FloatingOverlayMode: Equatable {
    case idle
    case recording
    case processing
    case failed

    var accessibilityLabel: String {
        switch self {
        case .idle: "Dictation idle"
        case .recording: "Dictation recording"
        case .processing: "Dictation processing"
        case .failed: "Dictation needs attention"
        }
    }

    var tint: Color {
        switch self {
        case .idle, .recording: .purple
        case .processing: .orange
        case .failed: .red
        }
    }

    var isActive: Bool {
        switch self {
        case .recording, .processing:
            true
        case .idle, .failed:
            false
        }
    }
}

private struct VoiceFlowHUD: View {
    var mode: FloatingOverlayMode
    var style: FloatingOverlayStyle
    var palette: FloatingOverlayPalette
    var level: Double
    var brightness: Double
    var spectrum: VoiceSpectrumBands
    var reduceMotion: Bool

    var body: some View {
        let colors = palette.resolvedColors

        VoiceFlowSymbol(
            level: mode == .recording ? level : 0,
            brightness: mode == .recording ? brightness : 0,
            spectrum: mode == .recording ? spectrum : .silent,
            mode: mode,
            style: style,
            palette: palette,
            reduceMotion: reduceMotion
        )
        .padding(.horizontal, overlayPadding.horizontal)
        .padding(.vertical, overlayPadding.vertical)
        .scaleEffect(mode == .idle ? idleScale : 1)
        .shadow(color: colors.shadowPrimary.opacity(mode.isActive ? 0.38 : 0.18), radius: mode.isActive ? 12 : 5)
        .shadow(color: colors.shadowSecondary.opacity(mode.isActive ? 0.18 : 0.08), radius: mode.isActive ? 9 : 3)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: mode)
    }

    private var overlayPadding: (horizontal: CGFloat, vertical: CGFloat) {
        switch style {
        case .voiceBars:
            (mode == .recording ? 6 : 5, mode == .recording ? 4 : 3)
        case .liquidFlow:
            (mode == .recording ? 7 : 5, mode == .recording ? 6 : 4)
        case .spectrumBloom:
            (mode == .recording ? 6 : 4, mode == .recording ? 4 : 3)
        case .minimalSignal:
            (mode == .recording ? 5 : 4, mode == .recording ? 5 : 3)
        case .signalHelix:
            (mode == .recording ? 7 : 5, mode == .recording ? 5 : 4)
        }
    }

    private var idleScale: CGFloat {
        switch style {
        case .voiceBars: 0.84
        case .liquidFlow: 0.82
        case .spectrumBloom: 0.72
        case .minimalSignal: 0.78
        case .signalHelix: 0.80
        }
    }
}

private struct VoiceFlowSymbol: View {
    var level: Double
    var brightness: Double
    var spectrum: VoiceSpectrumBands
    var mode: FloatingOverlayMode
    var style: FloatingOverlayStyle
    var palette: FloatingOverlayPalette
    var reduceMotion: Bool

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation) { context in
                    flowCanvas(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                flowCanvas(time: 0)
            }
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private var shouldAnimate: Bool {
        !reduceMotion && (mode == .recording || mode == .processing)
    }

    private func flowCanvas(time: TimeInterval) -> some View {
        Canvas { canvas, size in
            drawFlow(in: &canvas, size: size, time: time)
        }
    }

    private func drawFlow(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let activity = visualActivity
        let tone = visualBrightness
        let bands = visualSpectrum

        switch style {
        case .voiceBars:
            drawVoiceBars(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        case .liquidFlow:
            drawAmbientBloom(in: &canvas, size: size, activity: activity)
            drawRibbons(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
            drawLightNodes(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        case .spectrumBloom:
            drawSpectrumBloom(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        case .minimalSignal:
            drawMinimalSignal(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        case .signalHelix:
            drawSignalHelix(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        }
    }

    private func drawVoiceBars(
        in canvas: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let colors = palette.resolvedColors
        let rect = CGRect(
            x: size.width * 0.04,
            y: size.height * 0.12,
            width: size.width * 0.92,
            height: size.height * 0.76
        )
        let container = Path(roundedRect: rect, cornerRadius: rect.height * 0.28)
        let active = mode == .recording || mode == .processing

        canvas.fill(
            container,
            with: .color(colors.bloom.opacity(active ? 0.16 : 0.10))
        )
        canvas.stroke(
            container,
            with: .color(colors.shadowPrimary.opacity(active ? 0.22 : 0.14)),
            lineWidth: 1
        )

        if active {
            canvas.drawLayer { layer in
                layer.addFilter(.blur(radius: 7 + activity * 5))
                layer.fill(
                    Path(ellipseIn: rect.insetBy(dx: -8, dy: -7)),
                    with: .color(colors.shadowSecondary.opacity(0.10 + Double(activity * 0.10)))
                )
            }
        }

        let barCount = 7
        let centerY = rect.midY
        let spacing = rect.width / CGFloat(barCount + 1)
        let maxHeight = rect.height * 0.74
        let minHeight = rect.height * 0.16
        let phase = CGFloat(time * (mode == .idle ? 1.2 : 7.2 + Double(tone * 2.6)))
        let energies: [CGFloat] = [
            bands.low,
            (bands.low + bands.mid) / 2,
            bands.mid,
            (bands.mid + bands.high) / 2,
            bands.high,
            (bands.low + bands.high) / 2,
            bands.mid
        ]

        for index in 0..<barCount {
            let energy = mode == .idle ? CGFloat(0.08) : max(0.04, energies[index])
            let wave = 0.5 + 0.5 * sin(phase + CGFloat(index) * 0.82)
            let emphasis = CGFloat(index == 3 ? 1.0 : 0.72)
            let height = min(
                maxHeight,
                minHeight + (maxHeight * (0.18 + activity * 0.28 + energy * 0.52 + wave * 0.16) * emphasis)
            )
            let x = rect.minX + spacing * CGFloat(index + 1)
            let width = index == 3 ? CGFloat(5.4) : CGFloat(4.2)
            let barRect = CGRect(x: x - width / 2, y: centerY - height / 2, width: width, height: height)
            let barPath = Path(roundedRect: barRect, cornerRadius: width / 2)
            let color = colors.ribbonColors[index % colors.ribbonColors.count]

            canvas.stroke(
                barPath,
                with: .color(color.opacity(active ? 0.18 + Double(energy * 0.20) : 0.12)),
                style: StrokeStyle(lineWidth: 4.2, lineCap: .round)
            )
            canvas.fill(
                barPath,
                with: .color(color.opacity(active ? 0.62 + Double(activity * 0.26) : 0.42))
            )
        }
    }

    private func drawAmbientBloom(in canvas: inout GraphicsContext, size: CGSize, activity: CGFloat) {
        guard mode != .idle else { return }
        let colors = palette.resolvedColors
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let haloSize = CGSize(
            width: size.width * (0.58 + (activity * 0.18)),
            height: size.height * (0.42 + (activity * 0.26))
        )
        let haloRect = CGRect(
            x: center.x - haloSize.width / 2,
            y: center.y - haloSize.height / 2,
            width: haloSize.width,
            height: haloSize.height
        )

        canvas.drawLayer { layer in
            layer.addFilter(.blur(radius: 8 + (activity * 7)))
            layer.fill(
                Path(ellipseIn: haloRect),
                with: .color(colors.bloom.opacity(Double(0.18 + (activity * 0.16))))
            )
        }
    }

    private func drawRibbons(
        in canvas: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let colors = ribbonColors
        let strandCount = mode == .idle ? 3 : 5
        let phase = CGFloat(time * (mode == .idle ? 1.2 : 5.2 + Double(tone * 3.4)))

        for strand in 0..<strandCount {
            let normalizedLane = CGFloat(strand) - CGFloat(strandCount - 1) / 2
            let lane = strandCount == 1 ? 0 : normalizedLane / CGFloat(strandCount - 1)
            let bandEnergy = bandValue(for: strand, bands: bands)
            let path = makeRibbonPath(
                size: size,
                phase: phase + CGFloat(strand) * 0.74,
                lane: lane,
                activity: activity,
                tone: tone,
                bandEnergy: bandEnergy
            )
            let alphaBase: Double = mode == .idle ? 0.42 : 0.50
            let alpha = alphaBase + Double(activity * 0.26) + Double(bandEnergy * 0.22) - Double(abs(lane) * 0.12)
            let lineWidth = (mode == .idle ? CGFloat(1.0) : CGFloat(1.45)) + (activity * 1.0) + (tone * 0.34) + (bandEnergy * 1.55) - (abs(lane) * 0.45)
            let color = colors[strand % colors.count]

            canvas.stroke(
                path,
                with: .color(color.opacity(max(0.18, alpha * 0.34))),
                style: StrokeStyle(lineWidth: lineWidth + 5.4, lineCap: .round, lineJoin: .round)
            )
            canvas.stroke(
                path,
                with: .color(color.opacity(max(0.24, alpha))),
                style: StrokeStyle(lineWidth: max(0.8, lineWidth), lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func makeRibbonPath(
        size: CGSize,
        phase: CGFloat,
        lane: CGFloat,
        activity: CGFloat,
        tone: CGFloat,
        bandEnergy: CGFloat
    ) -> Path {
        let points = max(28, Int(size.width / 2.4))
        var path = Path()

        for index in 0...points {
            let progress = CGFloat(index) / CGFloat(points)
            let point = ribbonPoint(
                progress: progress,
                size: size,
                phase: phase,
                lane: lane,
                activity: activity,
                tone: tone,
                bandEnergy: bandEnergy
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func ribbonPoint(
        progress: CGFloat,
        size: CGSize,
        phase: CGFloat,
        lane: CGFloat,
        activity: CGFloat,
        tone: CGFloat,
        bandEnergy: CGFloat
    ) -> CGPoint {
        let xInset = size.width * 0.06
        let x = xInset + progress * (size.width - (xInset * 2))
        let centerY = size.height / 2
        let envelope = pow(sin(progress * .pi), 0.72)
        let voiceLift = mode == .recording ? activity : CGFloat(0.03)
        let amplitude = max(0.7, size.height * (0.06 + (voiceLift * 0.24) + (bandEnergy * 0.22)))
        let laneOffset = lane * size.height * (0.18 + voiceLift * 0.06 + bandEnergy * 0.05)
        let primary = sin((progress * .pi * 3.1) + phase)
        let secondary = sin((progress * .pi * (7.2 + tone * 2.6 + bandEnergy * 1.5)) - (phase * 0.56) + lane) * (0.26 + tone * 0.16 + bandEnergy * 0.16)
        let tertiary = sin((progress * .pi * (11.0 + tone * 5.0 + bandEnergy * 3.0)) + (phase * 0.28)) * (0.07 + tone * 0.12 + bandEnergy * 0.10)
        let y = centerY + laneOffset + (primary + secondary + tertiary) * amplitude * envelope
        return CGPoint(x: x, y: y)
    }

    private func drawLightNodes(
        in canvas: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let nodeCount = mode == .idle ? 2 : 4 + Int(((tone + bands.high) * 1.8).rounded())
        let phase = CGFloat(time * (mode == .idle ? 1.0 : 5.0 + Double(tone * 3.2)))

        for node in 0..<nodeCount {
            let travel = CGFloat(time).truncatingRemainder(dividingBy: 1.85) / 1.85
            let progress = (CGFloat(node) * 0.19 + travel).truncatingRemainder(dividingBy: 1)
            let lane = sin(CGFloat(node) * 1.7 + phase * 0.08) * (mode == .idle ? 0.12 : 0.28)
            let point = ribbonPoint(
                progress: progress,
                size: size,
                phase: phase,
                lane: lane,
                activity: activity,
                tone: tone,
                bandEnergy: bandValue(for: node, bands: bands)
            )
            let radius = (mode == .idle ? CGFloat(0.9) : CGFloat(1.25)) + activity * 0.7 + bandValue(for: node, bands: bands) * 1.6
            let nodeRect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let color = ribbonColors[node % ribbonColors.count]
            canvas.fill(Path(ellipseIn: nodeRect), with: .color(color.opacity(mode == .idle ? 0.58 : 0.84)))

            guard mode != .idle else { continue }
            let glowRadius = radius * (2.6 + activity)
            let glowRect = CGRect(x: point.x - glowRadius, y: point.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            canvas.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.10 + Double(activity * 0.10))))
        }
    }

    private func drawSpectrumBloom(
        in canvas: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let energies = [bands.low, bands.mid, bands.high]
        let colors = palette.resolvedColors.bandColors
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseRadius = min(size.width, size.height) * 0.16

        for layerIndex in 0..<3 {
            let energy = mode == .idle ? CGFloat(0.06) : max(0.04, energies[layerIndex])
            let phase = CGFloat(time * (1.0 + Double(layerIndex) * 0.46 + Double(tone) * 1.2))
            var path = Path()
            let pointCount = 84

            for pointIndex in 0...pointCount {
                let progress = CGFloat(pointIndex) / CGFloat(pointCount)
                let angle = progress * .pi * 2
                let harmonic = CGFloat(layerIndex + 3)
                let pulse = sin((angle * harmonic) + phase) * (0.12 + energy * 0.20)
                let ripple = sin((angle * (harmonic + 4)) - phase * 0.7) * (0.04 + tone * 0.06)
                let radius = baseRadius
                    + CGFloat(layerIndex) * min(size.width, size.height) * 0.075
                    + min(size.width, size.height) * (energy * 0.19 + activity * 0.04)
                let point = CGPoint(
                    x: center.x + cos(angle) * radius * (1 + pulse + ripple),
                    y: center.y + sin(angle) * radius * (0.72 + pulse - ripple)
                )

                if pointIndex == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.closeSubpath()
            let color = colors[layerIndex]
            canvas.stroke(
                path,
                with: .color(color.opacity(0.16 + Double(energy * 0.22))),
                style: StrokeStyle(lineWidth: 5.0 + energy * 5.0, lineCap: .round, lineJoin: .round)
            )
            canvas.stroke(
                path,
                with: .color(color.opacity(0.48 + Double(energy * 0.38))),
                style: StrokeStyle(lineWidth: 1.0 + energy * 1.6, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawMinimalSignal(
        in canvas: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let energies = [bands.low, bands.mid, bands.high]
        let colors = palette.resolvedColors.bandColors
        let centerY = size.height / 2
        let spacing = size.width / 4.8
        let centerX = size.width / 2
        let phase = CGFloat(time * (mode == .idle ? 1.3 : 5.0 + Double(tone * 2.0)))

        for index in 0..<3 {
            let energy = mode == .idle ? CGFloat(0.05) : max(0.03, energies[index])
            let x = centerX + (CGFloat(index) - 1) * spacing
            let height = size.height * (0.20 + activity * 0.18 + energy * 0.48)
            let wobble = sin(phase + CGFloat(index) * 1.2) * size.width * (0.012 + energy * 0.018)
            var path = Path()
            path.move(to: CGPoint(x: x - wobble, y: centerY - height / 2))
            path.addCurve(
                to: CGPoint(x: x + wobble, y: centerY + height / 2),
                control1: CGPoint(x: x + wobble * 2.2, y: centerY - height * 0.20),
                control2: CGPoint(x: x - wobble * 2.2, y: centerY + height * 0.20)
            )

            let color = colors[index]
            canvas.stroke(
                path,
                with: .color(color.opacity(0.22 + Double(energy * 0.24))),
                style: StrokeStyle(lineWidth: 6 + energy * 5, lineCap: .round, lineJoin: .round)
            )
            canvas.stroke(
                path,
                with: .color(color.opacity(0.66 + Double(energy * 0.28))),
                style: StrokeStyle(lineWidth: 1.6 + energy * 2.0, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawSignalHelix(
        in canvas: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let colors = palette.resolvedColors
        let centerY = size.height / 2
        let phase = CGFloat(time * (mode == .idle ? 1.2 : 6.8 + Double(tone * 4.0)))
        let lift = mode == .recording ? activity : CGFloat(0.08)
        let xInset = size.width * 0.08
        let width = size.width - (xInset * 2)
        let amplitude = size.height * (0.13 + lift * 0.24 + bands.high * 0.13)

        let upper = helixPath(
            size: size,
            xInset: xInset,
            width: width,
            centerY: centerY,
            amplitude: amplitude,
            phase: phase,
            verticalBias: -0.5,
            bands: bands
        )
        let lower = helixPath(
            size: size,
            xInset: xInset,
            width: width,
            centerY: centerY,
            amplitude: amplitude,
            phase: phase + .pi,
            verticalBias: 0.5,
            bands: bands
        )

        canvas.drawLayer { layer in
            layer.addFilter(.blur(radius: 5 + lift * 4))
            layer.stroke(
                upper,
                with: .color(colors.shadowSecondary.opacity(Double(0.18 + lift * 0.18))),
                style: StrokeStyle(lineWidth: 9 + lift * 7, lineCap: .round, lineJoin: .round)
            )
            layer.stroke(
                lower,
                with: .color(colors.shadowPrimary.opacity(Double(0.16 + lift * 0.16))),
                style: StrokeStyle(lineWidth: 8 + lift * 6, lineCap: .round, lineJoin: .round)
            )
        }

        canvas.stroke(
            upper,
            with: .linearGradient(
                Gradient(colors: [
                    colors.ribbonColors[0].opacity(0.72),
                    colors.ribbonColors[2 % colors.ribbonColors.count].opacity(0.94),
                    colors.ribbonColors[4 % colors.ribbonColors.count].opacity(0.74)
                ]),
                startPoint: CGPoint(x: xInset, y: 0),
                endPoint: CGPoint(x: xInset + width, y: size.height)
            ),
            style: StrokeStyle(lineWidth: 1.9 + lift * 1.9 + bands.mid * 1.2, lineCap: .round, lineJoin: .round)
        )
        canvas.stroke(
            lower,
            with: .linearGradient(
                Gradient(colors: [
                    colors.ribbonColors[3 % colors.ribbonColors.count].opacity(0.72),
                    colors.ribbonColors[1 % colors.ribbonColors.count].opacity(0.96),
                    colors.ribbonColors[0].opacity(0.70)
                ]),
                startPoint: CGPoint(x: xInset, y: size.height),
                endPoint: CGPoint(x: xInset + width, y: 0)
            ),
            style: StrokeStyle(lineWidth: 1.6 + lift * 1.6 + bands.low * 1.3, lineCap: .round, lineJoin: .round)
        )

        drawHelixBeatBars(
            in: &canvas,
            size: size,
            xInset: xInset,
            width: width,
            centerY: centerY,
            time: time,
            activity: lift,
            tone: tone,
            bands: bands
        )
        drawHelixHighlights(
            in: &canvas,
            size: size,
            xInset: xInset,
            width: width,
            centerY: centerY,
            phase: phase,
            activity: lift,
            bands: bands
        )
    }

    private func helixPath(
        size: CGSize,
        xInset: CGFloat,
        width: CGFloat,
        centerY: CGFloat,
        amplitude: CGFloat,
        phase: CGFloat,
        verticalBias: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) -> Path {
        let points = max(40, Int(size.width / 1.8))
        var path = Path()

        for index in 0...points {
            let progress = CGFloat(index) / CGFloat(points)
            let envelope = pow(sin(progress * .pi), 0.54)
            let band = bandValue(for: index, bands: bands)
            let wave = sin(progress * .pi * 3.6 + phase)
            let detail = sin(progress * .pi * (8.5 + band * 4.0) - phase * 0.45) * (0.16 + band * 0.22)
            let x = xInset + progress * width
            let y = centerY
                + verticalBias * size.height * 0.08
                + (wave + detail) * amplitude * envelope

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func drawHelixBeatBars(
        in canvas: inout GraphicsContext,
        size: CGSize,
        xInset: CGFloat,
        width: CGFloat,
        centerY: CGFloat,
        time: TimeInterval,
        activity: CGFloat,
        tone: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let colors = palette.resolvedColors.bandColors
        let barCount = 9
        let phase = CGFloat(time * (mode == .idle ? 1.0 : 8.0 + Double(tone * 3.0)))

        for index in 0..<barCount {
            let progress = CGFloat(index) / CGFloat(max(1, barCount - 1))
            let energy = max(0.03, bandValue(for: index, bands: bands))
            let wave = 0.5 + 0.5 * sin(phase + progress * .pi * 2)
            let height = size.height * (0.18 + activity * 0.30 + energy * 0.42 + wave * 0.10)
            let x = xInset + progress * width
            let rect = CGRect(x: x - 1.1, y: centerY - height / 2, width: 2.2, height: height)
            let path = Path(roundedRect: rect, cornerRadius: 2.0)
            let color = colors[index % colors.count]

            canvas.stroke(
                path,
                with: .color(color.opacity(0.18 + Double(energy * 0.28))),
                style: StrokeStyle(lineWidth: 5.0, lineCap: .round)
            )
            canvas.fill(path, with: .color(color.opacity(0.52 + Double(activity * 0.30))))
        }
    }

    private func drawHelixHighlights(
        in canvas: inout GraphicsContext,
        size: CGSize,
        xInset: CGFloat,
        width: CGFloat,
        centerY: CGFloat,
        phase: CGFloat,
        activity: CGFloat,
        bands: (low: CGFloat, mid: CGFloat, high: CGFloat)
    ) {
        let colors = palette.resolvedColors.ribbonColors
        let count = mode == .idle ? 2 : 4

        for index in 0..<count {
            let offset = (CGFloat(index) * 0.26 + CGFloat(phase).truncatingRemainder(dividingBy: .pi * 2) / (.pi * 2))
                .truncatingRemainder(dividingBy: 1)
            let envelope = pow(sin(offset * .pi), 0.58)
            let band = bandValue(for: index, bands: bands)
            let x = xInset + offset * width
            let y = centerY + sin(offset * .pi * 3.6 + phase) * size.height * (0.14 + activity * 0.18 + band * 0.10) * envelope
            let radius = 1.8 + activity * 2.0 + band * 1.6
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            let color = colors[index % colors.count]

            canvas.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(0.66 + Double(activity * 0.22)))
            )
        }
    }

    private var visualActivity: CGFloat {
        switch mode {
        case .idle:
            0.04
        case .recording:
            CGFloat(min(1, max(0.10, level)))
        case .processing:
            0.20
        case .failed:
            0.12
        }
    }

    private var visualBrightness: CGFloat {
        switch mode {
        case .recording:
            CGFloat(min(1, max(0, brightness)))
        case .processing:
            0.32
        case .idle, .failed:
            0.08
        }
    }

    private var visualSpectrum: (low: CGFloat, mid: CGFloat, high: CGFloat) {
        switch mode {
        case .recording:
            (
                CGFloat(min(1, max(0, spectrum.low))),
                CGFloat(min(1, max(0, spectrum.mid))),
                CGFloat(min(1, max(0, spectrum.high)))
            )
        case .processing:
            (0.14, 0.22, 0.18)
        case .idle:
            (0.03, 0.05, 0.04)
        case .failed:
            (0.10, 0.04, 0.16)
        }
    }

    private func bandValue(for index: Int, bands: (low: CGFloat, mid: CGFloat, high: CGFloat)) -> CGFloat {
        switch index % 5 {
        case 0: bands.low
        case 1: bands.mid
        case 2: bands.high
        case 3: (bands.low + bands.mid) / 2
        default: (bands.mid + bands.high) / 2
        }
    }

    private var ribbonColors: [Color] {
        let colors = palette.resolvedColors
        switch mode {
        case .failed:
            return colors.failedColors
        case .processing:
            return colors.processingColors
        case .idle, .recording:
            return colors.ribbonColors
        }
    }
}

private struct OverlayPaletteColors {
    var ribbonColors: [Color]
    var bandColors: [Color]
    var processingColors: [Color]
    var failedColors: [Color]
    var bloom: Color
    var shadowPrimary: Color
    var shadowSecondary: Color
}

private extension FloatingOverlayPalette {
    var resolvedColors: OverlayPaletteColors {
        switch self {
        case .scrivora:
            OverlayPaletteColors(
                ribbonColors: [
                    BrandColor.terracottaDeep,
                    BrandColor.terracotta,
                    BrandColor.terracottaLight,
                    BrandColor.mutedSage,
                    BrandColor.slate,
                    BrandColor.terracotta,
                    BrandColor.mutedSage
                ],
                bandColors: [
                    BrandColor.terracotta,
                    BrandColor.mutedSage,
                    BrandColor.terracottaLight
                ],
                processingColors: [
                    BrandColor.terracottaLight,
                    BrandColor.terracotta,
                    BrandColor.slate
                ],
                failedColors: [
                    .red,
                    BrandColor.terracottaDeep,
                    BrandColor.slate
                ],
                bloom: BrandColor.paper,
                shadowPrimary: BrandColor.terracotta,
                shadowSecondary: BrandColor.mutedSage
            )
        case .aurora:
            OverlayPaletteColors(
                ribbonColors: [
                    Color(red: 0.98, green: 0.24, blue: 0.92),
                    Color(red: 0.58, green: 0.30, blue: 1.0),
                    Color(red: 0.24, green: 0.76, blue: 1.0),
                    Color(red: 0.84, green: 0.18, blue: 1.0),
                    Color(red: 0.36, green: 0.92, blue: 0.86)
                ],
                bandColors: [
                    Color(red: 0.30, green: 0.76, blue: 1.0),
                    Color(red: 0.68, green: 0.24, blue: 1.0),
                    Color(red: 1.0, green: 0.24, blue: 0.86)
                ],
                processingColors: [
                    Color(red: 1.0, green: 0.58, blue: 0.20),
                    Color(red: 1.0, green: 0.28, blue: 0.74),
                    Color(red: 0.46, green: 0.40, blue: 1.0)
                ],
                failedColors: [
                    Color(red: 1.0, green: 0.20, blue: 0.32),
                    Color(red: 1.0, green: 0.52, blue: 0.28),
                    Color(red: 1.0, green: 0.12, blue: 0.64)
                ],
                bloom: Color(red: 0.63, green: 0.2, blue: 1),
                shadowPrimary: Color(red: 0.82, green: 0.18, blue: 1),
                shadowSecondary: Color(red: 0.18, green: 0.68, blue: 1)
            )
        case .graphite:
            OverlayPaletteColors(
                ribbonColors: [
                    Color(white: 0.18),
                    Color(white: 0.34),
                    Color(white: 0.52),
                    Color(white: 0.70),
                    Color(white: 0.86)
                ],
                bandColors: [
                    Color(white: 0.28),
                    Color(white: 0.56),
                    Color(white: 0.82)
                ],
                processingColors: [
                    Color(white: 0.42),
                    Color(white: 0.64),
                    Color(white: 0.78)
                ],
                failedColors: [
                    Color(white: 0.18),
                    Color(white: 0.36),
                    Color(white: 0.58)
                ],
                bloom: Color(white: 0.46),
                shadowPrimary: Color(white: 0.18),
                shadowSecondary: Color(white: 0.70)
            )
        case .ink:
            OverlayPaletteColors(
                ribbonColors: [
                    Color(white: 0.02),
                    Color(white: 0.08),
                    Color(white: 0.14),
                    Color(white: 0.22),
                    Color(white: 0.32)
                ],
                bandColors: [
                    Color(white: 0.04),
                    Color(white: 0.16),
                    Color(white: 0.30)
                ],
                processingColors: [
                    Color(white: 0.12),
                    Color(white: 0.22),
                    Color(white: 0.34)
                ],
                failedColors: [
                    Color(white: 0.04),
                    Color(white: 0.14),
                    Color(white: 0.28)
                ],
                bloom: Color(white: 0.05),
                shadowPrimary: Color.black,
                shadowSecondary: Color(white: 0.24)
            )
        case .silver:
            OverlayPaletteColors(
                ribbonColors: [
                    Color(white: 0.52),
                    Color(white: 0.66),
                    Color(white: 0.78),
                    Color(white: 0.88),
                    Color(white: 0.96)
                ],
                bandColors: [
                    Color(white: 0.58),
                    Color(white: 0.76),
                    Color(white: 0.94)
                ],
                processingColors: [
                    Color(white: 0.62),
                    Color(white: 0.78),
                    Color(white: 0.92)
                ],
                failedColors: [
                    Color(white: 0.48),
                    Color(white: 0.68),
                    Color(white: 0.84)
                ],
                bloom: Color(white: 0.82),
                shadowPrimary: Color(white: 0.64),
                shadowSecondary: Color.white
            )
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    private var wordCount: Int {
        appState.history.reduce(0) { total, record in
            total + record.finalTranscript.split { $0.isWhitespace || $0.isNewline }.count
        }
    }

    private var latestASRText: String {
        let visibleTranscript = appState.partialTranscript.isEmpty
            ? appState.finalTranscript
            : appState.partialTranscript
        if !visibleTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return visibleTranscript
        }
        return appState.history.first?.finalTranscript ?? ""
    }

    var body: some View {
        HomeHeroCard()

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
            CompactStat(title: "Total Words", value: "\(wordCount)", detail: "saved locally")
            CompactStat(title: "Dictations", value: "\(appState.history.count)", detail: "history")
            LastASRCard(latency: appState.latestMetrics.speechEndToFinalASR)
        }

        if let error = appState.lastError {
            Panel("Needs Attention") {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if needsPermissionAttention {
            PermissionsSummaryPanel()
        }

        LatestTranscriptsPanel(
            currentTranscript: latestASRText,
            records: Array(appState.history.prefix(5))
        )
    }

    private var needsPermissionAttention: Bool {
        appState.microphonePermission != .granted || appState.accessibilityPermission != .granted
    }
}

private struct HomeHeroCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    StatusPill(appState.selectedModel?.displayName ?? "No model", color: modelColor)
                    StatusPill(appState.settings.privacy.privacyMode ? "Maximum privacy" : "Local memory", color: BrandColor.mutedSage)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Speak, and your Mac writes.")
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("Scrivora records locally, transcribes on your Mac, and pastes text into the focused app.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Text("Hold")
                        .font(.title3.weight(.semibold))
                    KeyCap("Control")
                    Text("to dictate anywhere")
                        .font(.title3.weight(.semibold))
                }
            }

            Spacer(minLength: 16)

            HomeLogoPulse(
                isActive: appState.runtimeState.isCapturing,
                level: appState.voiceLevel
            )
                .frame(width: 220, height: 138)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .opacity(appState.runtimeState == .processing ? 0.55 : 1)
                .onTapGesture {
                    guard appState.runtimeState != .processing else { return }
                    appState.toggleDictation()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Start or stop dictation")
                .accessibilityHint(appState.runtimeState == .processing ? "Transcription is processing" : "Starts or stops Scrivora dictation")
                .accessibilityAction {
                    guard appState.runtimeState != .processing else { return }
                    appState.toggleDictation()
                }
                .help(appState.runtimeState == .processing ? "Transcription is processing" : "Start or stop dictation")
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.26), lineWidth: 1)
        )
    }

    private var modelColor: Color {
        guard let selected = appState.selectedModel else { return .orange }
        return selected.backend == .fluidAudio ? BrandColor.terracotta : BrandColor.mutedSage
    }
}

private struct HomeLogoPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isActive: Bool
    var level: Double

    var body: some View {
        TimelineView(.animation) { context in
            let seconds = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let pulse = isActive ? 0.72 + sin(seconds * 5) * 0.18 + level * 0.18 : 0.72

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(BrandColor.charcoal.opacity(0.18))

                Canvas { graphicsContext, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for index in 0..<3 {
                        let progress = CGFloat(index) / 3
                        let radius = 42 + progress * 34 + CGFloat(pulse) * (isActive ? 12 : 4)
                        let rect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        let opacity = Double(0.18 - progress * 0.04)
                        graphicsContext.stroke(
                            Path(ellipseIn: rect),
                            with: .color(BrandColor.terracotta.opacity(opacity)),
                            lineWidth: 2
                        )
                    }
                }

                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index == 2 ? BrandColor.terracotta : BrandColor.mutedSage.opacity(0.78))
                            .frame(width: 5, height: barHeight(index: index, pulse: pulse))
                    }
                }
                .offset(x: 54)

                ScrivoraAppIconMark()
                    .frame(width: 78, height: 78)
                    .shadow(color: BrandColor.terracotta.opacity(isActive ? 0.28 : 0.18), radius: 18, y: 6)
                    .offset(x: -38)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BrandColor.terracotta.opacity(0.24), lineWidth: 1)
        )
    }

    private func barHeight(index: Int, pulse: Double) -> CGFloat {
        let base: [CGFloat] = [24, 42, 68, 42, 24]
        let boost = CGFloat(isActive ? pulse * 18 : pulse * 5)
        return base[index] + boost
    }
}

private struct CompactStat: View {
    var title: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(value)
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.24), lineWidth: 1)
        )
    }
}

private struct LastASRCard: View {
    var latency: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(latency.map { String(format: "%.2fs", $0) } ?? "--")
                .font(.system(size: 30, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Recognition")
                .font(.system(size: 14, weight: .semibold))
            Text("last result time")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.24), lineWidth: 1)
        )
    }
}

private struct LatestTranscriptsPanel: View {
    var currentTranscript: String
    var records: [HistoryRecord]
    @State private var copiedTextID: String?

    private var hasCurrentTranscript: Bool {
        !currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Panel("Latest Transcript", subtitle: "Copy current text or review recent dictations.") {
            VStack(alignment: .leading, spacing: 14) {
                if hasCurrentTranscript {
                    transcriptBlock(
                        id: "current",
                        title: "Current",
                        subtitle: "ready",
                        text: currentTranscript,
                        prominent: true
                    )
                } else {
                    Text("Your next dictation will appear here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !records.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(records) { record in
                            transcriptBlock(
                                id: record.id.uuidString,
                                title: record.createdAt.formatted(date: .omitted, time: .shortened),
                                subtitle: record.createdAt.formatted(date: .abbreviated, time: .omitted),
                                text: record.finalTranscript,
                                prominent: false
                            )
                        }
                    }
                }
            }
        }
    }

    private func transcriptBlock(
        id: String,
        title: String,
        subtitle: String,
        text: String,
        prominent: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: prominent ? 15 : 13, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(text.isEmpty ? "(empty transcript)" : text)
                    .font(.system(size: prominent ? 15 : 13, weight: prominent ? .medium : .regular))
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .lineLimit(prominent ? 4 : 2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TranscriptCopyButton(
                copied: copiedTextID == id,
                disabled: text.isEmpty
            ) {
                copy(text, id: id)
            }
        }
        .padding(prominent ? 14 : 11)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(prominent ? 0.88 : 0.55),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(prominent ? 0.34 : 0.20), lineWidth: 1)
        )
    }

    private func copy(_ text: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedTextID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedTextID == id {
                copiedTextID = nil
            }
        }
    }
}

private struct TranscriptCopyButton: View {
    var copied: Bool
    var disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(disabled ? .secondary : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(nsColor: .controlBackgroundColor).opacity(disabled ? 0.40 : 0.88),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(copied ? BrandColor.mutedSage.opacity(0.42) : Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(disabled)
        .opacity(disabled ? 0.62 : 1)
        .help(copied ? "Copied" : "Copy transcript")
    }
}

private struct PermissionsSummaryPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Panel("Permissions", subtitle: "Allow recording and insertion once. macOS keeps control.") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    PermissionActionCard(
                        title: "Microphone",
                        detail: "Records your voice for local transcription.",
                        state: appState.microphonePermission,
                        systemImage: "mic.fill",
                        requestTitle: "Allow",
                        onRequest: appState.requestMicrophonePermission
                    )
                    PermissionActionCard(
                        title: "Accessibility",
                        detail: "Detects the shortcut and pastes text into the focused app.",
                        state: appState.accessibilityPermission,
                        systemImage: "cursorarrow.click.2",
                        requestTitle: "Allow",
                        onRequest: appState.requestAccessibilityPermission,
                        secondaryTitle: "Open Settings",
                        onSecondary: appState.openAccessibilitySettings
                    )
                }

                HStack {
                    Label("Audio is transcribed locally. Permissions stay controlled by macOS.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        appState.refreshPermissions()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

private struct UpdateAvailableOverlay: View {
    var update: AppUpdateManifest
    var currentVersion: String
    var statusMessage: String?
    var isInstalling: Bool
    var onCancel: () -> Void
    var onSkipVersion: () -> Void
    var onReleaseNotes: () -> Void
    var onInstall: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        update.critical ? "Critical Update Available" : "Update Available"
    }

    private var versionLabel: String {
        formattedVersion(update.version)
    }

    private var currentVersionLabel: String {
        formattedVersion(currentVersion)
    }

    private var downloadSize: String? {
        guard let archiveSizeBytes = update.archiveSizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: archiveSizeBytes, countStyle: .file)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.38 : 0.24))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Divider()

                VStack(alignment: .leading, spacing: 14) {
                    releaseSummary
                    releaseNotes

                    if let statusMessage, !statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(statusMessage, systemImage: isInstalling ? "arrow.down.circle.fill" : "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(22)

                Divider()

                footer
            }
            .frame(width: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.16), radius: 22, y: 14)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand(perform: onCancel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ScrivoraAppIconMark()
                .frame(width: 30, height: 30)
                .shadow(color: BrandColor.terracotta.opacity(0.20), radius: 7, y: 3)

            Text(title)
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close update dialog")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 15)
    }

    private var releaseSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(versionLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BrandColor.terracotta)

                UpdateMetadataPill(label: update.channel.capitalized, color: BrandColor.mutedSage)

                if update.critical {
                    UpdateMetadataPill(label: "Required", color: BrandColor.terracotta)
                }
            }

            Text("Current version \(currentVersionLabel), a new version is available.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let minimumSystemVersion = update.minimumSystemVersion {
                    UpdateMetadataPill(label: "macOS \(minimumSystemVersion)+", color: BrandColor.slate)
                }
                if let downloadSize {
                    UpdateMetadataPill(label: downloadSize, color: BrandColor.slate)
                }
                UpdateMetadataPill(label: "Verified download", color: BrandColor.mutedSage)
            }
        }
    }

    private var releaseNotes: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("What's New")
                .font(.system(size: 14, weight: .semibold))

            if update.notes.isEmpty {
                Text("Release notes are available from the release page.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(update.notes.enumerated()), id: \.offset) { _, note in
                            UpdateNoteRow(note: note)
                        }
                    }
                    .padding(.trailing, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 126)
                .scrollIndicators(.hidden)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                onReleaseNotes()
            } label: {
                Label("Notes", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(update.releaseNotesURL == nil || isInstalling)

            Spacer()

            Button("Cancel", action: onCancel)
                .disabled(isInstalling)

            Button("Skip Version", action: onSkipVersion)
                .disabled(isInstalling)

            Button(action: onInstall) {
                HStack(spacing: 8) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(isInstalling ? "Updating" : "Update Now")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(BrandColor.terracotta)
            .disabled(isInstalling)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34))
    }

    private func formattedVersion(_ version: String) -> String {
        version.lowercased().hasPrefix("v") ? version : "v\(version)"
    }
}

private struct UpdateMetadataPill: View {
    var label: String
    var color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct UpdateNoteRow: View {
    var note: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(BrandColor.terracotta)
                .frame(width: 5, height: 5)
            Text(note)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DictationCommandCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Hold")
                        .font(.system(size: 22, weight: .semibold))
                    KeyCap("Control")
                    Text("to dictate anywhere.")
                        .font(.system(size: 22, weight: .semibold))
                }

                Text(dictationBehaviorDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusPill(dictationModeLabel, color: BrandColor.terracotta)
                    StatusPill(stopModeLabel, color: BrandColor.mutedSage)
                    StatusPill(appState.settings.dictation.autoPaste ? "Auto-paste" : "Copy only", color: BrandColor.terracottaLight)
                }
            }

            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(BrandColor.terracotta.opacity(0.12))
                Image(systemName: appState.menuBarSystemImage)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(BrandColor.terracotta)
            }
            .frame(width: 86, height: 86)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, y: 5)
    }

    private var dictationModeLabel: String {
        if appState.settings.dictation.triggerMode == .holdControl {
            return "Press and hold"
        }
        switch appState.settings.dictation.mode {
        case .toggle:
            return "Toggle"
        case .pushToTalk:
            return "Push to talk"
        }
    }

    private var dictationBehaviorDescription: String {
        if appState.settings.dictation.triggerMode == .holdControl {
            return "Keep holding Control while you speak. Brief release slips are ignored; final text pastes after release."
        }
        return "Auto-stop listens for silence. Final text pastes into the focused field, with clipboard fallback when insertion fails."
    }

    private var stopModeLabel: String {
        if appState.settings.dictation.triggerMode == .holdControl {
            return "Release to stop"
        }
        return appState.settings.dictation.autoStopOnSilence ? "Silence stop on" : "Manual stop"
    }
}

private struct KeyCap: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
            )
    }
}

private struct PermissionActionCard: View {
    var title: String
    var detail: String
    var state: PermissionState
    var systemImage: String
    var requestTitle: String
    var onRequest: () -> Void
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(state == .granted ? 0.20 : 0.34), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.13))
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)
            StatusPill(state.label, color: tint)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            primaryButton

            if let secondaryTitle, let onSecondary {
                Button {
                    onSecondary()
                } label: {
                    Label(secondaryTitle, systemImage: "gearshape")
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var primaryButton: some View {
        if state == .granted {
            Button {
            } label: {
                Label("Allowed", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.bordered)
            .tint(tint)
            .disabled(true)
        } else {
            Button {
                onRequest()
            } label: {
                Label(requestTitle, systemImage: "arrow.right.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        }
    }

    private var tint: Color {
        state == .granted ? BrandColor.mutedSage : BrandColor.terracotta
    }
}

struct DictationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isRecordingShortcut = false

    var body: some View {
        PageHeader(
            title: "Controls",
            subtitle: "Choose how Scrivora starts, stops, and inserts text.",
            systemImage: "keyboard",
            accent: BrandColor.terracotta
        )

        DictationCommandCard()

        Panel("Shortcut", subtitle: "Hold Control is the fastest path for everyday dictation.") {
            VStack(spacing: 12) {
                ShortcutModeRow(
                    title: "Hold Control",
                    subtitle: "Hold Control to record. Brief accidental releases keep the same recording alive.",
                    keys: ["Control"],
                    isActive: appState.settings.dictation.triggerMode == .holdControl,
                    systemImage: "keyboard"
                ) {
                    appState.settings.dictation.triggerMode = .holdControl
                    appState.settings.dictation.shortcut = .default
                    appState.saveSettings()
                }

                ShortcutModeRow(
                    title: "Double-tap Control",
                    subtitle: "Double-tap Control to start and stop dictation without holding a key.",
                    keys: ["Control", "Control"],
                    isActive: appState.settings.dictation.triggerMode == .doubleTapControl,
                    systemImage: "hand.tap"
                ) {
                    appState.settings.dictation.triggerMode = .doubleTapControl
                    appState.saveSettings()
                }

                ShortcutModeRow(
                    title: "Custom Shortcut",
                    subtitle: "Record a keyboard shortcut if Hold Control conflicts with another app.",
                    keys: globalShortcutKeys,
                    isActive: appState.settings.dictation.triggerMode == .globalShortcut,
                    systemImage: "arrow.right.circle",
                    editAction: {
                        isRecordingShortcut = true
                    }
                ) {
                    appState.settings.dictation.triggerMode = .globalShortcut
                    appState.saveSettings()
                }
            }
        }
        .sheet(isPresented: $isRecordingShortcut) {
            ShortcutRecorderSheet(currentShortcut: appState.settings.dictation.shortcut) { shortcut in
                appState.settings.dictation.shortcut = shortcut
                appState.settings.dictation.triggerMode = .globalShortcut
                appState.saveSettings()
            }
        }

        Panel("Indicator", subtitle: "Choose the recording animation, color, and screen position.") {
            SettingToggleRow(
                title: "Show voice mark",
                subtitle: "Show the voice mark only while dictation is active.",
                systemImage: "waveform",
                tint: BrandColor.terracotta,
                isOn: Binding(
                    get: { appState.settings.dictation.showFloatingOverlay },
                    set: { appState.settings.dictation.showFloatingOverlay = $0; appState.saveSettings() }
                )
            )

            SettingToggleRow(
                title: "Sound effects",
                subtitle: "Play short local feedback when recording starts and stops.",
                systemImage: "speaker.wave.2",
                tint: BrandColor.mutedSage,
                isOn: Binding(
                    get: { appState.settings.dictation.startStopSound },
                    set: { appState.settings.dictation.startStopSound = $0; appState.saveSettings() }
                )
            )

            SettingControlRow("Animation", subtitle: "Choose the active dictation animation.", systemImage: "sparkles", tint: BrandColor.terracotta) {
                Picker("Animation", selection: Binding(
                    get: { appState.settings.dictation.floatingOverlayStyle },
                    set: { appState.settings.dictation.floatingOverlayStyle = $0; appState.saveSettings() }
                )) {
                    ForEach(FloatingOverlayStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            SettingControlRow("Color", subtitle: "Choose the color theme for the floating mark.", systemImage: "paintpalette", tint: BrandColor.mutedSage) {
                Picker("Color", selection: Binding(
                    get: { appState.settings.dictation.floatingOverlayPalette },
                    set: { appState.settings.dictation.floatingOverlayPalette = $0; appState.saveSettings() }
                )) {
                    ForEach(FloatingOverlayPalette.allCases, id: \.self) { palette in
                        Text(palette.displayName).tag(palette)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            SettingControlRow("Position", subtitle: "Place the floating mark where it stays out of your way.", systemImage: "rectangle.inset.filled.and.person.filled", tint: BrandColor.slate) {
                Picker("Position", selection: Binding(
                    get: { appState.settings.dictation.floatingOverlayPlacement },
                    set: { appState.settings.dictation.floatingOverlayPlacement = $0; appState.saveSettings() }
                )) {
                    ForEach(FloatingOverlayPlacement.allCases, id: \.self) { placement in
                        Text(placement.displayName).tag(placement)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }

        Panel("Insertion", subtitle: "Keep the paste path simple and predictable.") {
            SettingToggleRow(
                title: "Auto-paste final text",
                subtitle: "Insert the final transcript into the focused field automatically.",
                systemImage: "text.insert",
                tint: BrandColor.terracotta,
                isOn: Binding(
                get: { appState.settings.dictation.autoPaste },
                set: { appState.settings.dictation.autoPaste = $0; appState.saveSettings() }
                )
            )
            SettingToggleRow(
                title: "Copy transcript to clipboard",
                subtitle: "Keep a copy ready when direct insertion or paste is rejected.",
                systemImage: "doc.on.doc",
                tint: BrandColor.mutedSage,
                isOn: Binding(
                get: { appState.settings.dictation.copyToClipboard },
                set: { appState.settings.dictation.copyToClipboard = $0; appState.saveSettings() }
                )
            )
            SettingToggleRow(
                title: "Restore clipboard after paste",
                subtitle: "Put the previous clipboard content back after Scrivora inserts text.",
                systemImage: "arrow.uturn.backward",
                tint: BrandColor.terracottaLight,
                isOn: Binding(
                get: { appState.settings.dictation.restoreClipboardAfterPaste },
                set: { appState.settings.dictation.restoreClipboardAfterPaste = $0; appState.saveSettings() }
                )
            )
            InfoRow("Paste focus", appState.settings.dictation.pasteTargetBehavior.displayName)
            InfoRow("Restore delay", pasteDelayDescription)
        }
    }

    private var globalShortcutKeys: [String] {
        appState.settings.dictation.shortcut.keyCapLabels
    }

    private var pasteDelayDescription: String {
        if let delay = appState.settings.dictation.pasteStrategy.restoreDelayMilliseconds(
            customDelay: appState.settings.dictation.clipboardRestoreDelayMilliseconds
        ) {
            return "\(delay) ms"
        }
        return "No restore"
    }
}

struct ModelManagerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: ModelCatalogFilter = .all

    private var visibleModels: [ASRModelInfo] {
        appState.modelCatalog.models.filter { $0.isProductionReady }
    }

    private var filteredModels: [ASRModelInfo] {
        visibleModels.filter { model in
            filter.matches(model: model, isDownloaded: appState.isModelDownloaded(model))
        }
    }

    private var downloadedModels: [ASRModelInfo] {
        filteredModels
            .filter { appState.isModelDownloaded($0) }
    }

    private var availableModels: [ASRModelInfo] {
        filteredModels
            .filter { !appState.isModelDownloaded($0) }
    }

    var body: some View {
        PageHeader(
            title: "Models",
            subtitle: "Download one local model, then choose which one Scrivora uses.",
            systemImage: "cube.transparent",
            accent: BrandColor.terracotta
        )

        HStack(spacing: 12) {
            Picker("Model filter", selection: $filter) {
                ForEach(ModelCatalogFilter.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 520)

            Spacer()
        }

        if !downloadedModels.isEmpty {
            ModelLibrarySection(title: "Downloaded", models: downloadedModels)
        }

        ModelLibrarySection(
            title: "Available",
            models: availableModels
        )

        DisclosureGroup("Model storage") {
            HStack(spacing: 10) {
                Button {
                    appState.openWhisperModelFolder()
                } label: {
                    Label("Open Whisper Cache", systemImage: "folder")
                }
                Button {
                    appState.openFluidAudioModelFolder()
                } label: {
                    Label("Open FluidAudio Cache", systemImage: "folder.badge.gearshape")
                }
            }
            .padding(.top, 8)
        }
        .font(.callout)
        .foregroundStyle(.secondary)

        if let message = appState.modelDownloadMessage {
            Label(message, systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 2)
        }
    }
}

private enum ModelCatalogFilter: CaseIterable {
    case all
    case recommended
    case english
    case multilingual
    case local

    var title: String {
        switch self {
        case .all: "All"
        case .recommended: "Best"
        case .english: "English"
        case .multilingual: "Multilingual"
        case .local: "Downloaded"
        }
    }

    func matches(model: ASRModelInfo, isDownloaded: Bool) -> Bool {
        switch self {
        case .all:
            true
        case .recommended:
            model.isRecommended
        case .english:
            model.isEnglishOnly
        case .multilingual:
            !model.isEnglishOnly
        case .local:
            isDownloaded
        }
    }
}

private struct ModelLibrarySection: View {
    var title: String
    var models: [ASRModelInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Text("\(models.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.16), in: Capsule())
                Spacer()
            }

            if models.isEmpty {
                Text("No models match this filter.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(models) { model in
                        ModelCard(model: model)
                    }
                }
            }
        }
    }
}

private struct ModelCard: View {
    @EnvironmentObject private var appState: AppState
    let model: ASRModelInfo
    @State private var confirmDeleteModel = false

    private var isSelected: Bool {
        appState.selectedModel?.id == model.id
    }

    private var isDownloaded: Bool {
        appState.isModelDownloaded(model)
    }

    private var isDownloading: Bool {
        appState.isModelDownloading(model)
    }

    private var isDownloadable: Bool {
        model.backend == .fluidAudio || model.downloadURL != nil
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ModelGlyph(model: model, size: 42)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isSelected {
                        StatusPill("Using", color: BrandColor.mutedSage)
                    }
                    if model.isRecommended {
                        StatusPill("Best", color: BrandColor.terracotta)
                    }
                }

                ModelMetadataRow(model: model, compact: true)
            }

            Spacer(minLength: 8)

            if isDownloaded {
                Button(role: .destructive) {
                    confirmDeleteModel = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if isDownloadable {
                downloadButton
            } else {
                Label("Unavailable", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? BrandColor.terracotta.opacity(0.62) : Color(nsColor: .separatorColor).opacity(0.24), lineWidth: isSelected ? 1.5 : 1)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(BrandColor.terracotta)
                    .frame(width: 4)
                    .padding(.vertical, 16)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            if isDownloaded {
                appState.selectModel(model)
            } else if isDownloadable {
                appState.modelDownloadMessage = "Download \(model.displayName) first, then choose it as the default model."
            }
        }
        .confirmationDialog(
            "Delete \(model.displayName)?",
            isPresented: $confirmDeleteModel,
            titleVisibility: .visible
        ) {
            Button("Delete Model", role: .destructive) {
                appState.deleteModel(model)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the local model files for \(model.displayName). You can download them again later.")
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        Button {
            appState.downloadModel(model)
        } label: {
            if isDownloading {
                HStack(spacing: 7) {
                    ModelDownloadRing(progress: appState.downloadProgress(for: model), tint: tint)
                    Text("Downloading")
                }
            } else {
                Label("Download", systemImage: "arrow.down.circle.fill")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isDownloading)
    }

    private var cardBackground: Color {
        isSelected ? tint.opacity(0.09) : Color(nsColor: .controlBackgroundColor).opacity(0.78)
    }

    private var tint: Color {
        switch model.backend {
        case .fluidAudio: BrandColor.terracotta
        case .whisperCpp, .whisperKit: BrandColor.mutedSage
        case .mock: .secondary
        case .sherpaOnnx, .moonshine: BrandColor.terracottaLight
        }
    }

}

private struct ModelGlyph: View {
    var model: ASRModelInfo?
    var size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }

    private var tint: Color {
        guard let model else { return BrandColor.slate }
        return switch model.backend {
        case .fluidAudio: BrandColor.terracotta
        case .whisperCpp, .whisperKit: BrandColor.mutedSage
        case .sherpaOnnx, .moonshine: BrandColor.terracottaLight
        case .mock: BrandColor.slate
        }
    }

    private var systemImage: String {
        guard let model else { return "cube" }
        return switch model.backend {
        case .fluidAudio: "bolt.fill"
        case .whisperCpp: "waveform.badge.magnifyingglass"
        case .whisperKit: "sparkles"
        case .sherpaOnnx, .moonshine: "antenna.radiowaves.left.and.right"
        case .mock: "testtube.2"
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let shouldWrap = lineWidth > 0 && lineWidth + spacing + size.width > maxWidth
            if shouldWrap {
                totalWidth = max(totalWidth, lineWidth)
                totalHeight += lineHeight + rowSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += lineWidth == 0 ? size.width : spacing + size.width
                lineHeight = max(lineHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: proposal.width ?? totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + rowSpacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct ModelMetadataRow: View {
    var model: ASRModelInfo
    var compact: Bool

    var body: some View {
        FlowLayout(spacing: 7, rowSpacing: 6) {
            ModelBadge(model.familyName)
            ModelBadge(model.mode.displayLabel)
            ModelBadge(model.sizeText)
            ModelBadge(model.languageSummary)
            if model.supportsTranslation {
                ModelBadge("Translation")
            }
            ModelBadge(model.license)
        }
        .font(compact ? .caption : .callout)
    }
}

private struct ModelDownloadRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double?
    var tint: Color

    var body: some View {
        TimelineView(.animation) { context in
            let clamped = progress.map { min(0.995, max(0.02, $0)) }
            let seconds = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let rotation = clamped == nil ? Angle.degrees(seconds.truncatingRemainder(dividingBy: 1.2) / 1.2 * 360) : .zero

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.24), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: clamped ?? 0.32)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(rotation)
                Image(systemName: "arrow.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(tint)
                    .opacity(clamped == nil ? 0.75 : 1)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityLabel("Downloading model files")
    }
}

private struct ModelBadge: View {
    var text: String
    var inverted: Bool

    init(_ text: String, inverted: Bool = false) {
        self.text = text
        self.inverted = inverted
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeBackground, in: Capsule())
            .foregroundStyle(badgeForeground)
    }

    private var badgeBackground: Color {
        inverted ? Color(nsColor: .windowBackgroundColor).opacity(0.13) : Color(nsColor: .quaternaryLabelColor).opacity(0.18)
    }

    private var badgeForeground: Color {
        inverted ? Color(nsColor: .windowBackgroundColor).opacity(0.78) : Color.secondary
    }
}

private extension ASRUserMode {
    var displayLabel: String {
        switch self {
        case .instant: "Instant"
        case .balanced: "Balanced"
        case .accurate: "Accurate"
        case .highestQuality: "Highest"
        case .experimental: "Experimental"
        }
    }

}

private extension ASRModelInfo {
    var menuSystemImage: String {
        switch backend {
        case .fluidAudio: "bolt.fill"
        case .whisperCpp: "waveform.badge.magnifyingglass"
        case .whisperKit: "sparkles"
        case .sherpaOnnx: "antenna.radiowaves.left.and.right"
        case .moonshine: "moon"
        case .mock: "testtube.2"
        }
    }

    var familyName: String {
        switch backend {
        case .fluidAudio: "FluidAudio"
        case .whisperCpp: "Whisper.cpp"
        case .whisperKit: "WhisperKit"
        case .sherpaOnnx: "Sherpa ONNX"
        case .moonshine: "Moonshine"
        case .mock: "Mock"
        }
    }

    var isRecommended: Bool {
        id == "fluidaudio-parakeet-v3" || id == "whispercpp-large-v3-turbo-q5"
    }

    var isProductionReady: Bool {
        backend == .fluidAudio || backend == .whisperCpp
    }

    var isEnglishOnly: Bool {
        id.contains("-en-") || id.contains(".en") || id == "fluidaudio-parakeet-v2"
    }

    var languageSummary: String {
        if id == "fluidaudio-parakeet-v3" {
            return "25 languages"
        }
        return isEnglishOnly ? "English" : "Multilingual"
    }

    var supportsTranslation: Bool {
        backend == .whisperCpp && !isEnglishOnly && !id.contains("turbo")
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(estimatedSizeMB) * 1_000_000, countStyle: .file)
    }
}

private struct ToneOptionCard: View {
    var profile: DictationOutputProfile
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(tint.opacity(isSelected ? 0.18 : 0.12))
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 34, height: 34)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(BrandColor.mutedSage)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(isSelected ? BrandColor.terracotta.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? BrandColor.terracotta.opacity(0.35) : Color(nsColor: .separatorColor).opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        switch profile {
        case .automatic: BrandColor.terracotta
        case .general: BrandColor.mutedSage
        case .pragmatic: BrandColor.charcoal
        case .agent: BrandColor.terracottaLight
        case .email: BrandColor.mutedSage
        case .raw: BrandColor.slate
        }
    }

    private var systemImage: String {
        switch profile {
        case .automatic: "wand.and.sparkles"
        case .general: "text.alignleft"
        case .pragmatic: "chevron.left.forwardslash.chevron.right"
        case .agent: "terminal"
        case .email: "envelope"
        case .raw: "text.quote"
        }
    }

    private var detail: String {
        switch profile {
        case .automatic: "Picks a local writing style for the app you are using."
        case .general: "Readable everyday dictation with normal punctuation."
        case .pragmatic: "Sharper wording for coding apps, specs, and developer tools."
        case .agent: "Instruction-heavy style for agents, prompts, and task notes."
        case .email: "Clean sentence structure for mail, messages, and business writing."
        case .raw: "Minimal cleanup when exact transcript wording matters."
        }
    }
}

struct PostProcessingSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PageHeader(
            title: "Writing",
            subtitle: "Choose how Scrivora cleans text before paste.",
            systemImage: "slider.horizontal.3",
            accent: BrandColor.terracotta
        )

        Panel("Writing Style", subtitle: "Automatic adapts to the app you are using.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                ForEach(DictationOutputProfile.allCases, id: \.self) { profile in
                    ToneOptionCard(
                        profile: profile,
                        isSelected: appState.settings.postProcessing.outputProfile == profile
                    ) {
                        appState.settings.postProcessing.outputProfile = profile
                        appState.saveSettings()
                    }
                }
            }
        }

        Panel("Cleanup Strength", subtitle: "Formatting stays local and runs after transcription.") {
            SettingControlRow("Cleanup", subtitle: "Choose how aggressively Scrivora formats before paste.", systemImage: "wand.and.sparkles", tint: BrandColor.terracotta) {
                Picker("Cleanup", selection: Binding(
                    get: { appState.settings.postProcessing.cleanupMode },
                    set: { appState.settings.postProcessing.cleanupMode = $0; appState.saveSettings() }
                )) {
                    Text("Raw").tag(CleanupMode.raw)
                    Text("Fast").tag(CleanupMode.fast)
                    Text("Polished").tag(CleanupMode.polished)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            InfoRow("User dictionary", "\(appState.settings.postProcessing.userDictionary.count) entries")
            InfoRow("Corrections saved", "\(appState.improvementStats.correctionCount)")
            if let learningMessage = appState.learningMessage {
                Text(learningMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var visibleHistoryCount = 50
    @State private var confirmClearHistory = false

    var body: some View {
        PageHeader(
            title: "History",
            subtitle: "Review local transcripts and teach Scrivora your corrections.",
            systemImage: "doc.text",
            accent: BrandColor.mutedSage
        )

        HStack {
            if let learningMessage = appState.learningMessage {
                Text(learningMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !appState.history.isEmpty {
                Text("\(appState.history.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                confirmClearHistory = true
            } label: {
                Label("Clear History", systemImage: "trash")
            }
            .controlSize(.large)
            .disabled(appState.history.isEmpty)
        }
        .confirmationDialog(
            "Clear History?",
            isPresented: $confirmClearHistory,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                appState.clearHistory()
                visibleHistoryCount = 50
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved transcript history from this Mac. It does not delete models or settings.")
        }

        if appState.history.isEmpty {
            Panel("No saved dictations") {
                Text("Recent dictations appear here when transcript history is enabled.")
                    .foregroundStyle(.secondary)
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(visibleHistory) { record in
                    HistoryRecordRow(record: record)
                }
            }

            if hiddenHistoryCount > 0 {
                HStack {
                    Spacer()
                    Button {
                        visibleHistoryCount += 50
                    } label: {
                        Label("Show \(min(50, hiddenHistoryCount)) more", systemImage: "chevron.down")
                    }
                    .controlSize(.large)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private var visibleHistory: [HistoryRecord] {
        Array(appState.history.prefix(visibleHistoryCount))
    }

    private var hiddenHistoryCount: Int {
        max(0, appState.history.count - visibleHistory.count)
    }
}

struct HistoryRecordRow: View {
    @EnvironmentObject private var appState: AppState
    let record: HistoryRecord
    @State private var isCorrecting = false
    @State private var correctedTranscript = ""
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Button {
                    copyTranscript()
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.large)
                .disabled(record.finalTranscript.isEmpty)
                Button {
                    correctedTranscript = record.finalTranscript
                    isCorrecting = true
                } label: {
                    Label("Correct", systemImage: "sparkles")
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
            }

            Text(record.finalTranscript.isEmpty ? "(empty transcript)" : record.finalTranscript)
                .font(.body.weight(.medium))
                .textSelection(.enabled)
                .foregroundStyle(record.finalTranscript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isCorrecting {
                TextEditor(text: $correctedTranscript)
                    .font(.body)
                    .frame(minHeight: 88)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                    )
                HStack {
                    Button {
                        appState.learnCorrection(for: record, correctedTranscript: correctedTranscript)
                        isCorrecting = false
                    } label: {
                        Label("Save Correction", systemImage: "checkmark.circle.fill")
                    }
                    Button("Cancel") {
                        isCorrecting = false
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private func copyTranscript() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.finalTranscript, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }
}

private struct StorageUsageRow: View {
    let item: StorageUsageItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 16)
            Text(item.formattedSize)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
    }
}

private enum StorageDestructiveAction: Identifiable {
    case clearHistory
    case clearLearning
    case clearLocalTextData

    var id: String {
        switch self {
        case .clearHistory: "clearHistory"
        case .clearLearning: "clearLearning"
        case .clearLocalTextData: "clearLocalTextData"
        }
    }

    var title: String {
        switch self {
        case .clearHistory: "Clear History"
        case .clearLearning: "Clear Learning"
        case .clearLocalTextData: "Clear Local Text Data"
        }
    }

    var message: String {
        switch self {
        case .clearHistory:
            "This removes saved transcript history from this Mac. It does not delete learning memory, logs, settings, or models."
        case .clearLearning:
            "This removes correction memory and learned phrase rules. Future cleanup will no longer use those local corrections."
        case .clearLocalTextData:
            "This removes saved transcript history, correction memory, and performance logs from this Mac. Settings and models remain."
        }
    }

    var confirmTitle: String {
        switch self {
        case .clearHistory: "Clear History"
        case .clearLearning: "Clear Learning"
        case .clearLocalTextData: "Clear Local Text Data"
        }
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pendingStorageAction: StorageDestructiveAction?

    var body: some View {
        PageHeader(
            title: "Privacy",
            subtitle: "Local-first storage and permission controls.",
            systemImage: "lock.shield.fill",
            accent: BrandColor.mutedSage
        )

        PermissionsSummaryPanel()

        Panel("Privacy Preset", subtitle: "The fresh install default keeps the least local history.") {
            SettingsLine("Preset") {
                Picker("Preset", selection: Binding(
                    get: { visiblePrivacyProfile },
                    set: { appState.applyPrivacyChoice($0) }
                )) {
                    ForEach(visiblePrivacyProfiles, id: \.self) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            InfoRow("Current", visiblePrivacyProfile.displayName)
        }

        Panel("Data Policy", subtitle: "Audio is not saved by default.") {
            SettingToggleRow(
                title: "Privacy mode",
                subtitle: "Disable transcript history and learning memory for maximum local privacy.",
                systemImage: "lock.fill",
                tint: BrandColor.mutedSage,
                isOn: Binding(
                    get: { appState.settings.privacy.privacyMode },
                    set: { appState.setPrivacyMode($0) }
                )
            )
            SettingToggleRow(
                title: "Save transcript history",
                subtitle: "Store final dictations in History on this Mac.",
                systemImage: "doc.text",
                tint: BrandColor.terracotta,
                isOn: Binding(
                    get: { appState.settings.privacy.saveTranscriptHistory },
                    set: { appState.settings.privacy.saveTranscriptHistory = $0; appState.saveSettings() }
                )
            )
            SettingToggleRow(
                title: "Save learning memory",
                subtitle: "Keep local correction rules that improve cleanup over time.",
                systemImage: "sparkles",
                tint: BrandColor.terracottaLight,
                isOn: Binding(
                    get: { appState.settings.privacy.saveLearningMemory },
                    set: { appState.settings.privacy.saveLearningMemory = $0; appState.saveSettings() }
                )
            )
            SettingToggleRow(
                title: "Save audio",
                subtitle: "Keep raw recordings locally. Off by default.",
                systemImage: "waveform.circle",
                tint: BrandColor.terracottaDeep,
                isOn: Binding(
                    get: { appState.settings.privacy.saveAudio },
                    set: { appState.settings.privacy.saveAudio = $0; appState.saveSettings() }
                )
            )
        }

        Panel("Connection", subtitle: "Keep Scrivora offline when you only want installed local models.") {
            SettingToggleRow(
                title: "Offline mode",
                subtitle: "Block remote model downloads while keeping installed local models usable.",
                systemImage: "wifi.slash",
                tint: BrandColor.charcoal,
                isOn: Binding(
                    get: { appState.settings.privacy.offlineMode },
                    set: { appState.settings.privacy.offlineMode = $0; appState.saveSettings() }
                )
            )
        }

        Panel("Export", subtitle: "Write a local backup or a redacted support package.") {
            if let message = appState.privacyExportMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            HStack {
                Button {
                    appState.exportPrivacyData(options: .redactedDebugPackage)
                } label: {
                    Label("Export Support Package", systemImage: "square.and.arrow.up")
                }
                Button {
                    appState.exportPrivacyData(options: .fullLocalPackage)
                } label: {
                    Label("Export All Local Data", systemImage: "externaldrive")
                }
            }
            Text("Support export redacts transcript text, target metadata, and local paths. Full export includes saved local text.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Panel("Local Storage", subtitle: "Review and remove local data kept on this Mac.") {
            InfoRow("Total tracked storage", appState.totalLocalStorageSize)
            InfoRow("Data folder", appState.dataFolderPath)

            Divider()

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(appState.storageUsageItems) { item in
                    StorageUsageRow(item: item)
                    if item.id != appState.storageUsageItems.last?.id {
                        Divider()
                    }
                }
            }

            if let message = appState.storageStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    appState.refreshStorageUsage()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Button {
                    appState.openDataFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
            }

            Divider()

            HStack {
                Button(role: .destructive) {
                    pendingStorageAction = .clearHistory
                } label: {
                    Label("Clear History", systemImage: "clock.badge.xmark")
                }
                Button(role: .destructive) {
                    pendingStorageAction = .clearLearning
                } label: {
                    Label("Clear Learning", systemImage: "sparkles.rectangle.stack")
                }
            }

            Button(role: .destructive) {
                pendingStorageAction = .clearLocalTextData
            } label: {
                Label("Clear Local Text Data", systemImage: "trash")
            }
        }
        .confirmationDialog(
            pendingStorageAction?.title ?? "Confirm",
            isPresented: Binding(
                get: { pendingStorageAction != nil },
                set: { if !$0 { pendingStorageAction = nil } }
            ),
            presenting: pendingStorageAction
        ) { action in
            Button(action.confirmTitle, role: .destructive) {
                performDestructiveAction(action)
                pendingStorageAction = nil
            }
            Button("Cancel", role: .cancel) {
                pendingStorageAction = nil
            }
        } message: { action in
            Text(action.message)
        }
    }

    private func performDestructiveAction(_ action: StorageDestructiveAction) {
        switch action {
        case .clearHistory:
            appState.clearHistory()
        case .clearLearning:
            appState.clearCorrections()
        case .clearLocalTextData:
            appState.clearLocalTextData()
        }
    }

    private var visiblePrivacyProfiles: [PrivacyProfile] {
        [.maximumPrivacy, .balancedLocalMemory]
    }

    private var visiblePrivacyProfile: PrivacyProfile {
        appState.settings.privacy.selectedPrivacyProfile == .debugMode
            ? .balancedLocalMemory
            : appState.settings.privacy.selectedPrivacyProfile
    }
}

struct AboutView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PageHeader(
            title: AppBrand.productName,
            subtitle: AppBrand.tagline,
            systemImage: "info.circle.fill",
            accent: BrandColor.terracotta
        )

        Panel("Product") {
            HStack(alignment: .center, spacing: 18) {
                ScrivoraAppIconMark()
                    .frame(width: 72, height: 72)
                    .shadow(color: BrandColor.terracotta.opacity(0.20), radius: 12, y: 5)
                VStack(alignment: .leading, spacing: 7) {
                    Text(AppBrand.shortDescription)
                        .font(.headline)
                    Text(AppBrand.localFirstDescription)
                        .foregroundStyle(.secondary)
                    Text(AppBrand.privacyDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Panel("App") {
            InfoRow("Version", appState.appVersion)
            InfoRow("Website", AppBrand.websiteURL)
            InfoRow("macOS", "14 or newer")
        }

        UpdateControlsPanel()
    }
}

private struct UpdateControlsPanel: View {
    @EnvironmentObject private var appState: AppState

    private var manifestDisplay: String {
        let value = appState.settings.updates.manifestURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "scrivora.me" : value
    }

    var body: some View {
        Panel("Updates", subtitle: "Checks signed Scrivora release metadata.") {
            SettingToggleRow(
                title: "Automatic checks",
                subtitle: "Look for stable releases when Scrivora opens.",
                systemImage: "arrow.triangle.2.circlepath",
                tint: BrandColor.mutedSage,
                isOn: Binding(
                    get: { appState.settings.updates.automaticChecksEnabled },
                    set: { appState.setAutomaticUpdateChecks($0) }
                )
            )

            SettingToggleRow(
                title: "Prerelease builds",
                subtitle: "Include beta or prerelease channels when the manifest advertises them.",
                systemImage: "shippingbox",
                tint: BrandColor.terracotta,
                isOn: Binding(
                    get: { appState.settings.updates.includePrerelease },
                    set: { appState.setIncludePrereleaseUpdates($0) }
                )
            )

            InfoRow("Source", manifestDisplay)

            if let update = appState.availableUpdate {
                HStack(spacing: 10) {
                    StatusPill("Available", color: BrandColor.terracotta)
                    Text("Scrivora \(update.version)")
                        .font(.system(size: 14, weight: .semibold))
                    if update.critical {
                        StatusPill("Critical", color: .red)
                    }
                    Spacer()
                }
            }

            if let message = appState.updateStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await appState.checkForUpdates(manual: true) }
                } label: {
                    Label(appState.isCheckingForUpdates ? "Checking" : "Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isCheckingForUpdates)

                if appState.availableUpdate != nil {
                    Button {
                        appState.openAvailableUpdateReleaseNotes()
                    } label: {
                        Label("Release Notes", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(appState.availableUpdate?.releaseNotesURL == nil || appState.isInstallingUpdate)

                    Button {
                        appState.dismissUpdateAnnouncement()
                    } label: {
                        Label("Skip this version", systemImage: "xmark.circle")
                    }
                    .disabled(appState.isInstallingUpdate)

                    Button {
                        appState.installAvailableUpdate()
                    } label: {
                        Label(appState.isInstallingUpdate ? "Updating" : "Update Now", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandColor.terracotta)
                    .disabled(appState.isInstallingUpdate)
                }
            }
        }
    }
}
