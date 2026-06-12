import SwiftUI
import LocalVoiceFlowCore

private enum MainSection: String, CaseIterable, Identifiable {
    case dashboard
    case dictation
    case models
    case cleanup
    case history
    case privacy
    case debug
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .dictation: "Dictation"
        case .models: "AI Models"
        case .cleanup: "Cleanup"
        case .history: "History"
        case .privacy: "Privacy"
        case .debug: "Debug"
        case .about: "About"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard: "Status and usage"
        case .dictation: "Trigger and paste"
        case .models: "Local transcription"
        case .cleanup: "Profiles and learning"
        case .history: "Correct and learn"
        case .privacy: "Local data controls"
        case .debug: "Latency and routing"
        case .about: "Product details"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.bottom.50percent"
        case .dictation: "mic.fill"
        case .models: "brain.head.profile"
        case .cleanup: "wand.and.sparkles"
        case .history: "clock.arrow.circlepath"
        case .privacy: "lock.shield.fill"
        case .debug: "waveform.path.ecg"
        case .about: "info.circle.fill"
        }
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                appState.toggleDictation()
            } label: {
                Label(dictationButtonTitle, systemImage: appState.menuBarSystemImage)
            }

            Text(appState.runtimeState.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selected = appState.selectedModel {
                Divider()
                Text(selected.displayName)
                    .font(.caption.weight(.semibold))
                Text("\(selected.backend.rawValue) - \(selected.mode.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = appState.lastError {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(4)
            }

            Divider()
            Toggle("Privacy Mode", isOn: Binding(
                get: { appState.settings.privacy.privacyMode },
                set: { appState.setPrivacyMode($0) }
            ))
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open \(AppBrand.productName)", systemImage: "macwindow")
            }
            Button {
                appState.openDataFolder()
            } label: {
                Label("Open Data Folder", systemImage: "folder")
            }
            Divider()
            Button("Quit \(AppBrand.productName)") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 260)
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
    @State private var selection: MainSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarHeader()

                List(MainSection.allCases, selection: $selection) { section in
                    NavigationLink(value: section) {
                        Label {
                            Text(section.title)
                        } icon: {
                            Image(systemName: section.systemImage)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
            .navigationTitle(AppBrand.productName)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    detailView
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
                .frame(maxWidth: 980, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle((selection ?? .dashboard).title)
            .toolbar {
                ToolbarItemGroup {
                    if let selectedModel = appState.selectedModel {
                        ToolbarModelChip(
                            title: "ASR",
                            value: selectedModel.displayName,
                            color: selectedModel.backend == .fluidAudio ? .green : .blue
                        )
                    }
                    ToolbarModelChip(
                        title: "Profile",
                        value: appState.activeDictationProfile.profile.displayName,
                        color: .purple
                    )
                    StatusPill(appState.runtimeState.label, color: runtimeColor)
                    Button {
                        appState.toggleDictation()
                    } label: {
                        Label(dictationButtonTitle, systemImage: appState.menuBarSystemImage)
                    }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                }
            }
        }
        .frame(minWidth: 1080, minHeight: 720)
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
        case .debug:
            DebugPerformanceView()
        case .about:
            AboutView()
        }
    }

    private var dictationButtonTitle: String {
        switch appState.runtimeState {
        case .listening, .speechDetected, .partialTranscription:
            "Stop"
        default:
            "Dictate"
        }
    }

    private var runtimeColor: Color {
        switch appState.runtimeState {
        case .idle, .finished: .secondary
        case .listening: .blue
        case .speechDetected: .green
        case .partialTranscription: .teal
        case .processing: .orange
        case .failed: .red
        }
    }
}

private struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.purple.opacity(0.16))
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(AppBrand.productName)
                    .font(.system(size: 17, weight: .semibold))
                Text("Local dictation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

private struct ToolbarModelChip: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 30, weight: .semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.035), radius: 10, y: 4)
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
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

private struct MetricTile: View {
    var title: String
    var value: String
    var caption: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint.opacity(0.14))
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
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
                .foregroundStyle(.secondary)
            Spacer(minLength: 18)
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color ?? .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
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
                .foregroundStyle(.secondary)
            Spacer(minLength: 20)
            content
                .frame(maxWidth: 380, alignment: .trailing)
        }
        .font(.callout)
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
        case .liquidFlow:
            (mode == .recording ? 7 : 5, mode == .recording ? 6 : 4)
        case .spectrumBloom:
            (mode == .recording ? 6 : 4, mode == .recording ? 4 : 3)
        case .minimalSignal:
            (mode == .recording ? 5 : 4, mode == .recording ? 5 : 3)
        }
    }

    private var idleScale: CGFloat {
        switch style {
        case .liquidFlow: 0.82
        case .spectrumBloom: 0.72
        case .minimalSignal: 0.78
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
        case .liquidFlow:
            drawAmbientBloom(in: &canvas, size: size, activity: activity)
            drawRibbons(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
            drawLightNodes(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        case .spectrumBloom:
            drawSpectrumBloom(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
        case .minimalSignal:
            drawMinimalSignal(in: &canvas, size: size, time: time, activity: activity, tone: tone, bands: bands)
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

    var body: some View {
        PageHeader(
            title: "Ready for dictation",
            subtitle: "Hold Control, speak naturally, and paste polished local text into the focused app.",
            systemImage: "waveform.circle.fill",
            accent: .purple
        )

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 14)], spacing: 14) {
            MetricTile(
                title: "Dictations",
                value: "\(appState.history.count)",
                caption: "saved local sessions",
                systemImage: "mic.fill",
                tint: .pink
            )
            MetricTile(
                title: "Words Captured",
                value: "\(wordCount)",
                caption: "from saved transcripts",
                systemImage: "text.alignleft",
                tint: .blue
            )
            MetricTile(
                title: "Learned Rules",
                value: "\(appState.settings.postProcessing.userDictionary.count)",
                caption: "personal corrections",
                systemImage: "sparkles",
                tint: .green
            )
            MetricTile(
                title: "Final ASR",
                value: formatted(appState.latestMetrics.speechEndToFinalASR),
                caption: "speech end to text",
                systemImage: "speedometer",
                tint: .orange
            )
        }

        DictationCommandCard()

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 14)], spacing: 14) {
            Panel("Ready Status", subtitle: AppBrand.privacyDescription) {
                VStack(spacing: 10) {
                    InfoRow("Runtime", appState.runtimeState.label, color: runtimeColor)
                    InfoRow("Trigger", appState.settings.dictation.triggerMode.displayName)
                    InfoRow("Active model", appState.selectedModel?.displayName ?? "No model selected")
                    InfoRow("Target profile", appState.activeDictationProfile.profile.displayName)
                    if let error = appState.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Panel("Permissions", subtitle: "macOS access required for the core loop") {
                VStack(spacing: 10) {
                    PermissionRow(
                        title: "Microphone",
                        state: appState.microphonePermission,
                        requestTitle: "Request",
                        onRequest: appState.requestMicrophonePermission
                    )
                    PermissionRow(
                        title: "Accessibility",
                        state: appState.accessibilityPermission,
                        requestTitle: "Request",
                        onRequest: appState.requestAccessibilityPermission,
                        secondaryTitle: "Open Settings",
                        onSecondary: appState.openAccessibilitySettings
                    )
                    Button {
                        appState.refreshPermissions()
                    } label: {
                        Label("Refresh Permissions", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        if !appState.finalTranscript.isEmpty || !appState.partialTranscript.isEmpty {
            Panel("Latest Transcript") {
                Text(appState.partialTranscript.isEmpty ? appState.finalTranscript : appState.partialTranscript)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var runtimeColor: Color {
        switch appState.runtimeState {
        case .idle, .finished: .secondary
        case .listening: .blue
        case .speechDetected: .green
        case .partialTranscription: .teal
        case .processing: .orange
        case .failed: .red
        }
    }

    private func formatted(_ value: TimeInterval?) -> String {
        value.map { String(format: "%.2fs", $0) } ?? "--"
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

                Text("Auto-stop listens for silence. Final text pastes into the focused field, with clipboard fallback when insertion fails.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusPill(dictationModeLabel, color: .purple)
                    StatusPill(appState.settings.dictation.autoStopOnSilence ? "Silence stop on" : "Manual stop", color: .blue)
                    StatusPill(appState.settings.dictation.autoPaste ? "Paste on" : "Copy only", color: .green)
                }
            }

            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(.purple.opacity(0.12))
                Image(systemName: appState.menuBarSystemImage)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.purple)
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
        switch appState.settings.dictation.mode {
        case .toggle: "Toggle"
        case .pushToTalk: "Push to talk"
        }
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

private struct PermissionRow: View {
    var title: String
    var state: PermissionState
    var requestTitle: String
    var onRequest: () -> Void
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer(minLength: 12)
                StatusPill(state.label, color: state == .granted ? .green : .orange)
            }

            HStack(spacing: 8) {
                Button(requestTitle, action: onRequest)
                if let secondaryTitle, let onSecondary {
                    Button(secondaryTitle, action: onSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DictationSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PageHeader(
            title: "Dictation",
            subtitle: "Tune the start, stop, paste, and clipboard behavior.",
            systemImage: "mic.fill",
            accent: .pink
        )

        Panel("Trigger", subtitle: "Hold Control is the current fast path.") {
            SettingsLine("Mode") {
                Picker("Mode", selection: Binding(
                    get: { appState.settings.dictation.mode },
                    set: { appState.settings.dictation.mode = $0; appState.saveSettings() }
                )) {
                    Text("Toggle").tag(DictationMode.toggle)
                    Text("Push to talk").tag(DictationMode.pushToTalk)
                }
                .labelsHidden()
            }

            SettingsLine("Trigger") {
                Picker("Trigger", selection: Binding(
                    get: { appState.settings.dictation.triggerMode },
                    set: { appState.settings.dictation.triggerMode = $0; appState.saveSettings() }
                )) {
                    ForEach(TriggerMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
            }

            Stepper("Hold Control threshold: \(appState.settings.dictation.holdControlThresholdMilliseconds) ms", value: Binding(
                get: { appState.settings.dictation.holdControlThresholdMilliseconds },
                set: { appState.settings.dictation.holdControlThresholdMilliseconds = $0; appState.saveSettings() }
            ), in: 80...500, step: 10)

            Stepper("Double-tap interval: \(appState.settings.dictation.doubleTapControlIntervalMilliseconds) ms", value: Binding(
                get: { appState.settings.dictation.doubleTapControlIntervalMilliseconds },
                set: { appState.settings.dictation.doubleTapControlIntervalMilliseconds = $0; appState.saveSettings() }
            ), in: 150...700, step: 10)
        }

        Panel("Endpointing", subtitle: "Silence detection stops capture without saving audio.") {
            Toggle("Auto-stop on silence", isOn: Binding(
                get: { appState.settings.dictation.autoStopOnSilence },
                set: { appState.settings.dictation.autoStopOnSilence = $0; appState.saveSettings() }
            ))
            Stepper("Silence duration: \(appState.settings.dictation.silenceDurationMilliseconds) ms", value: Binding(
                get: { appState.settings.dictation.silenceDurationMilliseconds },
                set: { appState.settings.dictation.silenceDurationMilliseconds = $0; appState.saveSettings() }
            ), in: 300...2000, step: 100)
            Toggle("Show floating overlay", isOn: Binding(
                get: { appState.settings.dictation.showFloatingOverlay },
                set: { appState.settings.dictation.showFloatingOverlay = $0; appState.saveSettings() }
            ))

            SettingsLine("Overlay style") {
                Picker("Overlay style", selection: Binding(
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

            SettingsLine("Overlay palette") {
                Picker("Overlay palette", selection: Binding(
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
        }

        Panel("Insertion", subtitle: "Paste first, copy fallback when the target field rejects insertion.") {
            Toggle("Auto-paste final text", isOn: Binding(
                get: { appState.settings.dictation.autoPaste },
                set: { appState.settings.dictation.autoPaste = $0; appState.saveSettings() }
            ))
            Toggle("Copy transcript to clipboard", isOn: Binding(
                get: { appState.settings.dictation.copyToClipboard },
                set: { appState.settings.dictation.copyToClipboard = $0; appState.saveSettings() }
            ))
            Toggle("Restore clipboard after paste", isOn: Binding(
                get: { appState.settings.dictation.restoreClipboardAfterPaste },
                set: { appState.settings.dictation.restoreClipboardAfterPaste = $0; appState.saveSettings() }
            ))
            Stepper("Clipboard restore delay: \(appState.settings.dictation.clipboardRestoreDelayMilliseconds) ms", value: Binding(
                get: { appState.settings.dictation.clipboardRestoreDelayMilliseconds },
                set: { appState.settings.dictation.clipboardRestoreDelayMilliseconds = $0; appState.saveSettings() }
            ), in: 0...2000, step: 100)
        }
    }
}

private enum ModelFilter: String, CaseIterable, Identifiable {
    case recommended
    case parakeet
    case whisper
    case experimental

    var id: String { rawValue }
    var title: String {
        switch self {
        case .recommended: "Recommended"
        case .parakeet: "Parakeet"
        case .whisper: "Whisper"
        case .experimental: "Experimental"
        }
    }
}

struct ModelManagerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filter: ModelFilter = .recommended

    private var selectedModel: ASRModelInfo? {
        appState.selectedModel
    }

    private var visibleModels: [ASRModelInfo] {
        appState.modelCatalog.models.filter { model in
            switch filter {
            case .recommended:
                return [.fluidAudio, .whisperCpp].contains(model.backend)
            case .parakeet:
                return model.backend == .fluidAudio
            case .whisper:
                return model.backend == .whisperCpp || model.backend == .whisperKit
            case .experimental:
                return ![ASRBackend.fluidAudio, .whisperCpp].contains(model.backend)
            }
        }
    }

    var body: some View {
        PageHeader(
            title: "AI Models",
            subtitle: "Pick the local ASR engine that balances speed, accuracy, and privacy.",
            systemImage: "brain.head.profile",
            accent: .purple
        )

        Panel("Default Model", subtitle: "The active model stays loaded when possible.") {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedModel?.displayName ?? "No model selected")
                        .font(.system(size: 24, weight: .semibold))
                    Text(selectedModel.map { "\($0.backend.rawValue) - \($0.mode.rawValue.capitalized) - \($0.qualityLabel)" } ?? "Select a model below.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(appState.isModelDownloaded(selectedModel ?? appState.modelCatalog.models[0]) ? "Downloaded" : "Needs model", color: appState.isModelDownloaded(selectedModel ?? appState.modelCatalog.models[0]) ? .green : .orange)
            }
        }

        Picker("Model group", selection: $filter) {
            ForEach(ModelFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(visibleModels) { model in
                ModelCard(model: model)
            }
        }

        Panel("Advanced Paths", subtitle: "Only whisper.cpp uses these paths. Parakeet uses FluidAudio's model cache.") {
            Toggle("Prefer persistent whisper-server", isOn: Binding(
                get: { appState.settings.models.preferPersistentWhisperServer },
                set: { appState.setPreferPersistentWhisperServer($0) }
            ))
            TextField("Whisper server path", text: Binding(
                get: { appState.settings.models.whisperServerExecutablePath ?? "" },
                set: { appState.setWhisperServerPath($0) }
            ))
            TextField("Whisper binary path", text: Binding(
                get: { appState.settings.models.whisperExecutablePath ?? "" },
                set: { appState.setWhisperExecutablePath($0) }
            ))
            TextField("Model file override path", text: Binding(
                get: { appState.settings.models.customASRModelPath ?? "" },
                set: { appState.setCustomASRModelPath($0) }
            ))
            if let message = appState.modelDownloadMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ModelCard: View {
    @EnvironmentObject private var appState: AppState
    let model: ASRModelInfo

    private var isSelected: Bool {
        appState.settings.models.selectedASRModelID == model.id
    }

    private var isDownloaded: Bool {
        appState.isModelDownloaded(model)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: model.backend == .fluidAudio ? "bolt.fill" : "cpu")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                    if isSelected {
                        StatusPill("Default", color: .green)
                    }
                    if isDownloaded {
                        StatusPill("Local", color: .blue)
                    }
                }
                HStack(spacing: 8) {
                    ModelBadge(model.backend.rawValue)
                    ModelBadge(model.mode.rawValue.capitalized)
                    ModelBadge("\(model.estimatedSizeMB) MB")
                    ModelBadge(model.license)
                }
                Text("\(model.speedLabel) - \(model.qualityLabel). Uses about \(model.estimatedMemoryMB) MB RAM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    appState.selectModel(model)
                } label: {
                    Label(isSelected ? "Selected" : "Set Default", systemImage: isSelected ? "checkmark.circle.fill" : "arrow.right.circle")
                }
                .disabled(isSelected)

                Button {
                    isDownloaded ? appState.deleteModel(model) : appState.downloadModel(model)
                } label: {
                    Label(isDownloaded ? "Delete" : "Download", systemImage: isDownloaded ? "trash" : "arrow.down.circle")
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.green.opacity(0.55) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch model.backend {
        case .fluidAudio: .green
        case .whisperCpp, .whisperKit: .blue
        case .mock: .secondary
        case .sherpaOnnx, .moonshine: .orange
        }
    }
}

private struct ModelBadge: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.18), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

struct PostProcessingSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PageHeader(
            title: "Cleanup",
            subtitle: "Control how raw ASR becomes paste-ready text.",
            systemImage: "wand.and.sparkles",
            accent: .green
        )

        Panel("Output Profile", subtitle: "Automatic adapts to coding, agent, email, and writing apps.") {
            SettingsLine("Profile") {
                Picker("Output profile", selection: Binding(
                    get: { appState.settings.postProcessing.outputProfile },
                    set: { appState.settings.postProcessing.outputProfile = $0; appState.saveSettings() }
                )) {
                    ForEach(DictationOutputProfile.allCases, id: \.self) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
                .labelsHidden()
            }
            InfoRow("Current route", "\(appState.activeDictationProfile.profile.displayName) - \(appState.activeDictationProfile.category)")
            InfoRow("Reason", appState.activeDictationProfile.reason)
        }

        Panel("Deterministic Cleanup", subtitle: "Runs locally before paste.") {
            SettingsLine("Cleanup") {
                Picker("Cleanup", selection: Binding(
                    get: { appState.settings.postProcessing.cleanupMode },
                    set: { appState.settings.postProcessing.cleanupMode = $0; appState.saveSettings() }
                )) {
                    Text("Raw").tag(CleanupMode.raw)
                    Text("Fast").tag(CleanupMode.fast)
                    Text("Polished").tag(CleanupMode.polished)
                }
                .labelsHidden()
            }
            SettingsLine("Preset") {
                Picker("Preset", selection: Binding(
                    get: { appState.settings.postProcessing.preset },
                    set: { appState.settings.postProcessing.preset = $0; appState.saveSettings() }
                )) {
                    ForEach(PostProcessingPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .labelsHidden()
            }
            TextEditor(text: Binding(
                get: { appState.settings.postProcessing.customPrompt },
                set: { appState.settings.postProcessing.customPrompt = $0; appState.saveSettings() }
            ))
            .frame(minHeight: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
        }

        Panel("Learned Vocabulary", subtitle: "Correction memory improves future cleanup without cloud calls.") {
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

    var body: some View {
        PageHeader(
            title: "History",
            subtitle: "Review local transcripts and teach Scrivora your corrections.",
            systemImage: "clock.arrow.circlepath",
            accent: .orange
        )

        HStack {
            if let learningMessage = appState.learningMessage {
                Text(learningMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                appState.clearHistory()
            } label: {
                Label("Clear History", systemImage: "trash")
            }
        }

        if appState.history.isEmpty {
            Panel("No saved dictations") {
                Text("Dictations appear here when transcript history is enabled.")
                    .foregroundStyle(.secondary)
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(appState.history) { record in
                    HistoryRecordRow(record: record)
                }
            }
        }
    }
}

struct HistoryRecordRow: View {
    @EnvironmentObject private var appState: AppState
    let record: HistoryRecord
    @State private var isCorrecting = false
    @State private var correctedTranscript = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.finalTranscript.isEmpty ? "(empty transcript)" : record.finalTranscript)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(record.finalTranscript.isEmpty ? .secondary : .primary)
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    correctedTranscript = record.finalTranscript
                    isCorrecting = true
                } label: {
                    Label("Correct & Learn", systemImage: "sparkles")
                }
            }

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
                        Label("Learn Correction", systemImage: "checkmark.circle.fill")
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

    private var metadata: String {
        [
            record.createdAt.formatted(date: .abbreviated, time: .standard),
            record.targetAppName,
            record.outputProfile
        ]
        .compactMap(\.self)
        .joined(separator: " - ")
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

struct PrivacyView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PageHeader(
            title: "Privacy",
            subtitle: "Local-first storage and permission controls.",
            systemImage: "lock.shield.fill",
            accent: .teal
        )

        Panel("Data Policy", subtitle: "Audio is not saved by default.") {
            Toggle("Privacy mode", isOn: Binding(
                get: { appState.settings.privacy.privacyMode },
                set: { appState.setPrivacyMode($0) }
            ))
            Toggle("Save transcript history", isOn: Binding(
                get: { appState.settings.privacy.saveTranscriptHistory },
                set: { appState.settings.privacy.saveTranscriptHistory = $0; appState.saveSettings() }
            ))
            Toggle("Save audio", isOn: Binding(
                get: { appState.settings.privacy.saveAudio },
                set: { appState.settings.privacy.saveAudio = $0; appState.saveSettings() }
            ))
            Toggle("Offline mode", isOn: Binding(
                get: { appState.settings.privacy.offlineMode },
                set: { appState.settings.privacy.offlineMode = $0; appState.saveSettings() }
            ))
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
                    Label("Refresh Sizes", systemImage: "arrow.clockwise")
                }
                Button {
                    appState.openDataFolder()
                } label: {
                    Label("Open Data Folder", systemImage: "folder")
                }
            }

            Divider()

            HStack {
                Button(role: .destructive) {
                    appState.clearHistory()
                } label: {
                    Label("Clear History", systemImage: "clock.badge.xmark")
                }
                Button(role: .destructive) {
                    appState.clearCorrections()
                } label: {
                    Label("Clear Learning", systemImage: "sparkles.rectangle.stack")
                }
                Button(role: .destructive) {
                    appState.clearPerformanceLogs()
                } label: {
                    Label("Clear Logs", systemImage: "chart.xyaxis.line")
                }
            }

            Button(role: .destructive) {
                appState.clearLocalTextData()
            } label: {
                Label("Clear History, Learning, and Logs", systemImage: "trash")
            }
        }
    }
}

struct DebugPerformanceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PageHeader(
            title: "Debug",
            subtitle: "Latency, paste method, target app, and learning diagnostics.",
            systemImage: "waveform.path.ecg",
            accent: .red
        )

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
            MetricTile(title: "Hotkey -> Record", value: formatted(appState.latestMetrics.hotkeyToRecordingStart), caption: "trigger latency", systemImage: "keyboard", tint: .blue)
            MetricTile(title: "Record -> Speech", value: formatted(appState.latestMetrics.recordingStartToSpeechDetected), caption: "VAD detection", systemImage: "waveform", tint: .green)
            MetricTile(title: "First Partial", value: formatted(appState.latestMetrics.firstPartialLatency), caption: "overlay feedback", systemImage: "text.bubble", tint: .teal)
            MetricTile(title: "Speech -> ASR", value: formatted(appState.latestMetrics.speechEndToFinalASR), caption: "final transcript", systemImage: "speedometer", tint: .orange)
            MetricTile(title: "ASR -> Cleanup", value: formatted(appState.latestMetrics.finalASRToCleanup), caption: "post-processing", systemImage: "wand.and.sparkles", tint: .purple)
            MetricTile(title: "Cleanup -> Paste", value: formatted(appState.latestMetrics.cleanupToPaste), caption: "target insertion", systemImage: "doc.on.clipboard", tint: .pink)
        }

        Panel("Routing") {
            InfoRow("Trigger mode", appState.settings.dictation.triggerMode.displayName)
            InfoRow("Target app", appState.activeDictationProfile.targetAppName ?? "Not recorded")
            InfoRow("Target bundle", appState.activeDictationProfile.targetBundleIdentifier ?? "Not recorded")
            InfoRow("Output profile", appState.activeDictationProfile.profile.displayName)
            InfoRow("Profile category", appState.activeDictationProfile.category)
            InfoRow("Paste method", appState.latestMetrics.pasteMethod ?? "Not recorded")
            InfoRow("Profile reason", appState.activeDictationProfile.reason)
        }

        Panel("Improvement") {
            InfoRow("Corrections saved", "\(appState.improvementStats.correctionCount)")
            InfoRow("Learned phrase rules", "\(appState.settings.postProcessing.userDictionary.count)")
            InfoRow("Latest correction", appState.improvementStats.latestCorrectionAt?.formatted(date: .abbreviated, time: .standard) ?? "Not recorded")
            if let learningMessage = appState.learningMessage {
                Text(learningMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                appState.clearCorrections()
            } label: {
                Label("Clear Correction Memory", systemImage: "trash")
            }
        }
    }

    private func formatted(_ value: TimeInterval?) -> String {
        value.map { String(format: "%.3fs", $0) } ?? "--"
    }
}

struct AboutView: View {
    var body: some View {
        PageHeader(
            title: AppBrand.productName,
            subtitle: AppBrand.tagline,
            systemImage: "info.circle.fill",
            accent: .blue
        )

        Panel("Product") {
            Text(AppBrand.shortDescription)
            Text(AppBrand.localFirstDescription)
                .foregroundStyle(.secondary)
            Text(AppBrand.privacyDescription)
                .foregroundStyle(.secondary)
        }

        Panel("Build") {
            InfoRow("Target", "macOS 14+, Swift 6, SwiftPM")
            InfoRow("Bundle ID", AppBrand.bundleIdentifier)
            InfoRow("Installed app", AppBrand.installedAppPath)
        }
    }
}
