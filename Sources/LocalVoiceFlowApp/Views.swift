import SwiftUI
import LocalVoiceFlowCore

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(appState.runtimeState == .listening || appState.runtimeState == .speechDetected ? "Stop Dictation" : "Start Dictation") {
                appState.toggleDictation()
            }
            Text(appState.runtimeState.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let selected = appState.selectedModel {
                Divider()
                Text("Model: \(selected.displayName)")
                    .font(.caption)
                Text("Mode: \(selected.mode.rawValue.capitalized)")
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
            Button("Open Settings") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Open Data Folder") {
                appState.openDataFolder()
            }
            Divider()
            Button("Quit LocalVoiceFlow") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 260)
    }
}

struct PreferencesRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingView()
                Divider()
                DictationSettingsView()
                Divider()
                ModelManagerView()
                Divider()
                PostProcessingSettingsView()
                Divider()
                HistoryView()
                Divider()
                PrivacyView()
                Divider()
                DebugPerformanceView()
                Divider()
                AboutView()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}

private struct PreferenceSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct FloatingDictationOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(appState.runtimeState.label)
                    .font(.headline)
                Spacer()
                Image(systemName: appState.menuBarSystemImage)
                    .foregroundStyle(.secondary)
            }

            Text(overlayText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(8)
    }

    private var overlayText: String {
        if !appState.partialTranscript.isEmpty { return appState.partialTranscript }
        if !appState.finalTranscript.isEmpty { return appState.finalTranscript }
        if let error = appState.lastError { return error }
        return "Ready for local dictation."
    }

    private var statusColor: Color {
        switch appState.runtimeState {
        case .idle, .finished:
            .secondary
        case .listening:
            .blue
        case .speechDetected:
            .green
        case .processing:
            .orange
        case .failed:
            .red
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceSection("LocalVoiceFlow") {
                Text("A local-first macOS dictation assistant. Audio and transcript text stay on this Mac unless you explicitly download models.")
                Text("Data folder: \(appState.dataFolderPath)")
                    .font(.caption)
                    .textSelection(.enabled)
            }

            PreferenceSection("Permissions") {
                HStack {
                    Text("Microphone")
                    Spacer()
                    Text(appState.microphonePermission.label)
                        .foregroundStyle(appState.microphonePermission == .granted ? .green : .secondary)
                    Button("Request") { appState.requestMicrophonePermission() }
                }
                HStack {
                    Text("Accessibility")
                    Spacer()
                    Text(appState.accessibilityPermission.label)
                        .foregroundStyle(appState.accessibilityPermission == .granted ? .green : .secondary)
                    Button("Refresh") { appState.refreshPermissions() }
                    Button("Request") { appState.requestAccessibilityPermission() }
                    Button("Open Settings") { appState.openAccessibilitySettings() }
                }
            }

            PreferenceSection("Current State") {
                Text(appState.runtimeState.label)
                if !appState.finalTranscript.isEmpty {
                    Text(appState.finalTranscript)
                        .textSelection(.enabled)
                }
                if let error = appState.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct DictationSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PreferenceSection("Dictation") {
            Picker("Mode", selection: Binding(
                get: { appState.settings.dictation.mode },
                set: { appState.settings.dictation.mode = $0; appState.saveSettings() }
            )) {
                Text("Toggle").tag(DictationMode.toggle)
                Text("Push to talk").tag(DictationMode.pushToTalk)
            }

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
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct ModelManagerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ASR Models")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
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
                Text("Whisper paths apply to whisper.cpp models. Parakeet models use ~/Library/Application Support/FluidAudio/Models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(appState.modelCatalog.models) { model in
                    modelRow(model)
                }
            }
            if let message = appState.modelDownloadMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Direct download is enabled for whisper.cpp GGML files and FluidAudio Parakeet models. Parakeet may compile CoreML models on first load.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func modelRow(_ model: ASRModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.displayName)
                        .font(.headline)
                    Text("\(model.backend.rawValue) · \(model.speedLabel) · \(model.qualityLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(model.estimatedSizeMB) MB · \(model.estimatedMemoryMB) MB memory · \(model.license)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if appState.settings.models.selectedASRModelID == model.id {
                    Text("Selected")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            HStack {
                Button("Select") { appState.selectModel(model) }
                Button(appState.isModelDownloaded(model) ? "Delete" : "Download") {
                    appState.isModelDownloaded(model) ? appState.deleteModel(model) : appState.downloadModel(model)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PostProcessingSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PreferenceSection("Cleanup") {
            Picker("Cleanup", selection: Binding(
                get: { appState.settings.postProcessing.cleanupMode },
                set: { appState.settings.postProcessing.cleanupMode = $0; appState.saveSettings() }
            )) {
                Text("Raw").tag(CleanupMode.raw)
                Text("Fast").tag(CleanupMode.fast)
                Text("Polished").tag(CleanupMode.polished)
            }

            Picker("Preset", selection: Binding(
                get: { appState.settings.postProcessing.preset },
                set: { appState.settings.postProcessing.preset = $0; appState.saveSettings() }
            )) {
                ForEach(PostProcessingPreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            TextEditor(text: Binding(
                get: { appState.settings.postProcessing.customPrompt },
                set: { appState.settings.postProcessing.customPrompt = $0; appState.saveSettings() }
            ))
            .frame(minHeight: 120)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Local History")
                    .font(.headline)
                Spacer()
                Button("Clear") { appState.clearHistory() }
            }

            if appState.history.isEmpty {
                Text("No saved dictations yet.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(appState.history) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.finalTranscript)
                                .textSelection(.enabled)
                            Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PreferenceSection("Privacy") {
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
            LabeledContent("Data folder") {
                Text(appState.dataFolderPath)
                    .textSelection(.enabled)
            }
            Button("Open Data Folder") {
                appState.openDataFolder()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct DebugPerformanceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        PreferenceSection("Latency") {
            metric("Hotkey to recording", appState.latestMetrics.hotkeyToRecordingStart)
            metric("Recording to speech", appState.latestMetrics.recordingStartToSpeechDetected)
            metric("Speech end to ASR", appState.latestMetrics.speechEndToFinalASR)
            metric("ASR to cleanup", appState.latestMetrics.finalASRToCleanup)
            metric("Cleanup to paste", appState.latestMetrics.cleanupToPaste)
            metric("Speech end to inserted text", appState.latestMetrics.stopSpeakingToInsertedText)
            metric("Model load", appState.latestMetrics.modelLoadTime)
            metric("Model warmup", appState.latestMetrics.modelWarmupTime)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func metric(_ label: String, _ value: TimeInterval?) -> some View {
        LabeledContent(label) {
            Text(value.map { String(format: "%.3f s", $0) } ?? "Not recorded")
                .monospacedDigit()
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LocalVoiceFlow")
                .font(.largeTitle.weight(.semibold))
            Text("Native local dictation for macOS. No account, no subscription, no cloud transcription.")
                .foregroundStyle(.secondary)
            Text("MVP target: macOS 14+, Swift 6, Xcode 16 for app packaging. The SwiftPM runner can be built from Command Line Tools for core development.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
