import Foundation

public enum DictationMode: String, Codable, CaseIterable, Sendable {
    case toggle
    case pushToTalk
}

public enum TriggerMode: String, Codable, CaseIterable, Sendable {
    case globalShortcut
    case holdControl
    case doubleTapControl

    public var displayName: String {
        switch self {
        case .globalShortcut: "Global shortcut"
        case .holdControl: "Hold Control"
        case .doubleTapControl: "Double-tap Control"
        }
    }
}

public enum FloatingOverlayStyle: String, Codable, CaseIterable, Sendable {
    case liquidFlow
    case spectrumBloom
    case minimalSignal

    public var displayName: String {
        switch self {
        case .liquidFlow: "Liquid Flow"
        case .spectrumBloom: "Spectrum Bloom"
        case .minimalSignal: "Minimal Signal"
        }
    }
}

public enum FloatingOverlayPalette: String, Codable, CaseIterable, Sendable {
    case aurora
    case graphite
    case ink
    case silver

    public var displayName: String {
        switch self {
        case .aurora: "Aurora"
        case .graphite: "Graphite"
        case .ink: "Ink"
        case .silver: "Silver"
        }
    }
}

public enum CleanupMode: String, Codable, CaseIterable, Sendable {
    case raw
    case fast
    case polished
}

public enum PostProcessingPreset: String, Codable, CaseIterable, Sendable {
    case rawTranscription
    case cleanPunctuation
    case professionalEmail
    case casualMessage
    case bulletNotes
    case meetingNotes
    case codeComments
    case technicalWriting
    case customPrompt
}

public enum DictationOutputProfile: String, Codable, CaseIterable, Sendable {
    case automatic
    case general
    case pragmatic
    case agent
    case email
    case raw

    public var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .general: "General"
        case .pragmatic: "Pragmatic"
        case .agent: "Agent"
        case .email: "Email"
        case .raw: "Raw"
        }
    }
}

public enum ASRUserMode: String, Codable, CaseIterable, Sendable {
    case instant
    case balanced
    case accurate
    case highestQuality
    case experimental
}

public enum PrivacyProfile: String, Codable, CaseIterable, Sendable {
    case maximumPrivacy
    case balancedLocalMemory
    case debugMode

    public var displayName: String {
        switch self {
        case .maximumPrivacy: "Maximum Privacy"
        case .balancedLocalMemory: "Balanced Local Memory"
        case .debugMode: "Debug Mode"
        }
    }
}

public enum ShortcutModifier: String, Codable, CaseIterable, Sendable {
    case command
    case control
    case option
    case shift
}

public struct GlobalShortcut: Codable, Equatable, Sendable {
    public var key: String
    public var modifiers: [ShortcutModifier]

    public init(key: String, modifiers: [ShortcutModifier]) {
        self.key = key
        self.modifiers = modifiers
    }

    public static let `default` = GlobalShortcut(key: "control", modifiers: [])
    public static let legacyDefault = GlobalShortcut(key: "space", modifiers: [.control, .option])

    public var isControlTap: Bool {
        key.lowercased() == "control" && modifiers.isEmpty
    }

    public var displayName: String {
        if isControlTap {
            return "Control Tap"
        }
        let modifierText = modifiers.map(\.rawValue.capitalized).joined(separator: "+")
        return modifierText.isEmpty ? key.uppercased() : "\(modifierText)+\(key.uppercased())"
    }
}

public struct DictationSettings: Codable, Equatable, Sendable {
    public var shortcut: GlobalShortcut
    public var triggerMode: TriggerMode
    public var mode: DictationMode
    public var autoStopOnSilence: Bool
    public var silenceDurationMilliseconds: Int
    public var holdControlThresholdMilliseconds: Int
    public var doubleTapControlIntervalMilliseconds: Int
    public var startStopSound: Bool
    public var showFloatingOverlay: Bool
    public var floatingOverlayStyle: FloatingOverlayStyle
    public var floatingOverlayPalette: FloatingOverlayPalette
    public var autoPaste: Bool
    public var copyToClipboard: Bool
    public var restoreClipboardAfterPaste: Bool
    public var clipboardRestoreDelayMilliseconds: Int
    public var longDictationMode: Bool
    public var selectedInputDeviceID: String?

    public init(
        shortcut: GlobalShortcut = .default,
        triggerMode: TriggerMode = .holdControl,
        mode: DictationMode = .toggle,
        autoStopOnSilence: Bool = true,
        silenceDurationMilliseconds: Int = 700,
        holdControlThresholdMilliseconds: Int = 150,
        doubleTapControlIntervalMilliseconds: Int = 320,
        startStopSound: Bool = true,
        showFloatingOverlay: Bool = true,
        floatingOverlayStyle: FloatingOverlayStyle = .liquidFlow,
        floatingOverlayPalette: FloatingOverlayPalette = .aurora,
        autoPaste: Bool = true,
        copyToClipboard: Bool = true,
        restoreClipboardAfterPaste: Bool = true,
        clipboardRestoreDelayMilliseconds: Int = 600,
        longDictationMode: Bool = false,
        selectedInputDeviceID: String? = nil
    ) {
        self.shortcut = shortcut
        self.triggerMode = triggerMode
        self.mode = mode
        self.autoStopOnSilence = autoStopOnSilence
        self.silenceDurationMilliseconds = silenceDurationMilliseconds
        self.holdControlThresholdMilliseconds = holdControlThresholdMilliseconds
        self.doubleTapControlIntervalMilliseconds = doubleTapControlIntervalMilliseconds
        self.startStopSound = startStopSound
        self.showFloatingOverlay = showFloatingOverlay
        self.floatingOverlayStyle = floatingOverlayStyle
        self.floatingOverlayPalette = floatingOverlayPalette
        self.autoPaste = autoPaste
        self.copyToClipboard = copyToClipboard
        self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
        self.clipboardRestoreDelayMilliseconds = clipboardRestoreDelayMilliseconds
        self.longDictationMode = longDictationMode
        self.selectedInputDeviceID = selectedInputDeviceID
    }

    private enum CodingKeys: String, CodingKey {
        case shortcut
        case triggerMode
        case mode
        case autoStopOnSilence
        case silenceDurationMilliseconds
        case holdControlThresholdMilliseconds
        case doubleTapControlIntervalMilliseconds
        case startStopSound
        case showFloatingOverlay
        case floatingOverlayStyle
        case floatingOverlayPalette
        case autoPaste
        case copyToClipboard
        case restoreClipboardAfterPaste
        case clipboardRestoreDelayMilliseconds
        case longDictationMode
        case selectedInputDeviceID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.shortcut = try container.decodeIfPresent(GlobalShortcut.self, forKey: .shortcut) ?? .default
        self.triggerMode = try container.decodeIfPresent(TriggerMode.self, forKey: .triggerMode) ?? .holdControl
        self.mode = try container.decodeIfPresent(DictationMode.self, forKey: .mode) ?? .toggle
        self.autoStopOnSilence = try container.decodeIfPresent(Bool.self, forKey: .autoStopOnSilence) ?? true
        self.silenceDurationMilliseconds = try container.decodeIfPresent(Int.self, forKey: .silenceDurationMilliseconds) ?? 700
        self.holdControlThresholdMilliseconds = try container.decodeIfPresent(Int.self, forKey: .holdControlThresholdMilliseconds) ?? 150
        self.doubleTapControlIntervalMilliseconds = try container.decodeIfPresent(Int.self, forKey: .doubleTapControlIntervalMilliseconds) ?? 320
        self.startStopSound = try container.decodeIfPresent(Bool.self, forKey: .startStopSound) ?? true
        self.showFloatingOverlay = try container.decodeIfPresent(Bool.self, forKey: .showFloatingOverlay) ?? true
        self.floatingOverlayStyle = try container.decodeIfPresent(FloatingOverlayStyle.self, forKey: .floatingOverlayStyle) ?? .liquidFlow
        self.floatingOverlayPalette = try container.decodeIfPresent(FloatingOverlayPalette.self, forKey: .floatingOverlayPalette) ?? .aurora
        self.autoPaste = try container.decodeIfPresent(Bool.self, forKey: .autoPaste) ?? true
        self.copyToClipboard = try container.decodeIfPresent(Bool.self, forKey: .copyToClipboard) ?? true
        self.restoreClipboardAfterPaste = try container.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? true
        self.clipboardRestoreDelayMilliseconds = try container.decodeIfPresent(Int.self, forKey: .clipboardRestoreDelayMilliseconds) ?? 600
        self.longDictationMode = try container.decodeIfPresent(Bool.self, forKey: .longDictationMode) ?? false
        self.selectedInputDeviceID = try container.decodeIfPresent(String.self, forKey: .selectedInputDeviceID)
    }
}

public struct ModelSettings: Codable, Equatable, Sendable {
    public var selectedASRModelID: String
    public var selectedLLMModelID: String?
    public var selectedASRMode: ASRUserMode
    public var useMetalAcceleration: Bool
    public var preferQuantizedModels: Bool
    public var whisperExecutablePath: String?
    public var customASRModelPath: String?
    public var whisperServerExecutablePath: String?
    public var preferPersistentWhisperServer: Bool

    public init(
        selectedASRModelID: String = "fluidaudio-parakeet-v2",
        selectedLLMModelID: String? = nil,
        selectedASRMode: ASRUserMode = .instant,
        useMetalAcceleration: Bool = true,
        preferQuantizedModels: Bool = true,
        whisperExecutablePath: String? = nil,
        customASRModelPath: String? = nil,
        whisperServerExecutablePath: String? = nil,
        preferPersistentWhisperServer: Bool = true
    ) {
        self.selectedASRModelID = selectedASRModelID
        self.selectedLLMModelID = selectedLLMModelID
        self.selectedASRMode = selectedASRMode
        self.useMetalAcceleration = useMetalAcceleration
        self.preferQuantizedModels = preferQuantizedModels
        self.whisperExecutablePath = whisperExecutablePath
        self.customASRModelPath = customASRModelPath
        self.whisperServerExecutablePath = whisperServerExecutablePath
        self.preferPersistentWhisperServer = preferPersistentWhisperServer
    }

    private enum CodingKeys: String, CodingKey {
        case selectedASRModelID
        case selectedLLMModelID
        case selectedASRMode
        case useMetalAcceleration
        case preferQuantizedModels
        case whisperExecutablePath
        case customASRModelPath
        case whisperServerExecutablePath
        case preferPersistentWhisperServer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedASRModelID = try container.decodeIfPresent(String.self, forKey: .selectedASRModelID) ?? "fluidaudio-parakeet-v2"
        self.selectedLLMModelID = try container.decodeIfPresent(String.self, forKey: .selectedLLMModelID)
        self.selectedASRMode = try container.decodeIfPresent(ASRUserMode.self, forKey: .selectedASRMode) ?? .instant
        self.useMetalAcceleration = try container.decodeIfPresent(Bool.self, forKey: .useMetalAcceleration) ?? true
        self.preferQuantizedModels = try container.decodeIfPresent(Bool.self, forKey: .preferQuantizedModels) ?? true
        self.whisperExecutablePath = try container.decodeIfPresent(String.self, forKey: .whisperExecutablePath)
        self.customASRModelPath = try container.decodeIfPresent(String.self, forKey: .customASRModelPath)
        self.whisperServerExecutablePath = try container.decodeIfPresent(String.self, forKey: .whisperServerExecutablePath)
        self.preferPersistentWhisperServer = try container.decodeIfPresent(Bool.self, forKey: .preferPersistentWhisperServer) ?? true
    }
}

public struct PostProcessingSettings: Codable, Equatable, Sendable {
    public var cleanupMode: CleanupMode
    public var preset: PostProcessingPreset
    public var outputProfile: DictationOutputProfile
    public var customPrompt: String
    public var customReplacements: [CustomReplacement]
    public var userDictionary: [UserDictionaryEntry]

    public init(
        cleanupMode: CleanupMode = .fast,
        preset: PostProcessingPreset = .cleanPunctuation,
        outputProfile: DictationOutputProfile = .automatic,
        customPrompt: String = "",
        customReplacements: [CustomReplacement] = CustomReplacement.defaults,
        userDictionary: [UserDictionaryEntry] = []
    ) {
        self.cleanupMode = cleanupMode
        self.preset = preset
        self.outputProfile = outputProfile
        self.customPrompt = customPrompt
        self.customReplacements = customReplacements
        self.userDictionary = userDictionary
    }

    private enum CodingKeys: String, CodingKey {
        case cleanupMode
        case preset
        case outputProfile
        case customPrompt
        case customReplacements
        case userDictionary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cleanupMode = try container.decodeIfPresent(CleanupMode.self, forKey: .cleanupMode) ?? .fast
        self.preset = try container.decodeIfPresent(PostProcessingPreset.self, forKey: .preset) ?? .cleanPunctuation
        self.outputProfile = try container.decodeIfPresent(DictationOutputProfile.self, forKey: .outputProfile) ?? .automatic
        self.customPrompt = try container.decodeIfPresent(String.self, forKey: .customPrompt) ?? ""
        self.customReplacements = try container.decodeIfPresent([CustomReplacement].self, forKey: .customReplacements) ?? CustomReplacement.defaults
        self.userDictionary = try container.decodeIfPresent([UserDictionaryEntry].self, forKey: .userDictionary) ?? []
    }
}

public struct PrivacySettings: Codable, Equatable, Sendable {
    public var privacyMode: Bool
    public var saveTranscriptHistory: Bool
    public var saveLearningMemory: Bool
    public var savePerformanceLogs: Bool
    public var includeTargetAppInLogs: Bool
    public var includeTargetBundleIdentifierInLogs: Bool
    public var saveAudio: Bool
    public var offlineMode: Bool
    public var analyticsEnabled: Bool
    public var firstRunPrivacyChoiceCompleted: Bool
    public var selectedPrivacyProfile: PrivacyProfile

    public init(
        privacyMode: Bool = true,
        saveTranscriptHistory: Bool = false,
        saveLearningMemory: Bool = false,
        savePerformanceLogs: Bool = true,
        includeTargetAppInLogs: Bool = false,
        includeTargetBundleIdentifierInLogs: Bool = false,
        saveAudio: Bool = false,
        offlineMode: Bool = false,
        analyticsEnabled: Bool = false,
        firstRunPrivacyChoiceCompleted: Bool = false,
        selectedPrivacyProfile: PrivacyProfile = .maximumPrivacy
    ) {
        self.privacyMode = privacyMode
        self.saveTranscriptHistory = saveTranscriptHistory
        self.saveLearningMemory = saveLearningMemory
        self.savePerformanceLogs = savePerformanceLogs
        self.includeTargetAppInLogs = includeTargetAppInLogs
        self.includeTargetBundleIdentifierInLogs = includeTargetBundleIdentifierInLogs
        self.saveAudio = saveAudio
        self.offlineMode = offlineMode
        self.analyticsEnabled = analyticsEnabled
        self.firstRunPrivacyChoiceCompleted = firstRunPrivacyChoiceCompleted
        self.selectedPrivacyProfile = selectedPrivacyProfile
    }

    private enum CodingKeys: String, CodingKey {
        case privacyMode
        case saveTranscriptHistory
        case saveLearningMemory
        case savePerformanceLogs
        case includeTargetAppInLogs
        case includeTargetBundleIdentifierInLogs
        case saveAudio
        case offlineMode
        case analyticsEnabled
        case firstRunPrivacyChoiceCompleted
        case selectedPrivacyProfile
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPrivacyMode = try container.decodeIfPresent(Bool.self, forKey: .privacyMode) ?? true
        let decodedSaveTranscriptHistory = try container.decodeIfPresent(Bool.self, forKey: .saveTranscriptHistory) ?? false
        let decodedSaveLearningMemory = try container.decodeIfPresent(Bool.self, forKey: .saveLearningMemory) ?? decodedSaveTranscriptHistory
        let decodedSavePerformanceLogs = try container.decodeIfPresent(Bool.self, forKey: .savePerformanceLogs) ?? true
        self.privacyMode = decodedPrivacyMode
        self.saveTranscriptHistory = decodedSaveTranscriptHistory
        self.saveLearningMemory = decodedSaveLearningMemory
        self.savePerformanceLogs = decodedSavePerformanceLogs
        self.includeTargetAppInLogs = try container.decodeIfPresent(Bool.self, forKey: .includeTargetAppInLogs) ?? false
        self.includeTargetBundleIdentifierInLogs = try container.decodeIfPresent(Bool.self, forKey: .includeTargetBundleIdentifierInLogs) ?? false
        self.saveAudio = try container.decodeIfPresent(Bool.self, forKey: .saveAudio) ?? false
        self.offlineMode = try container.decodeIfPresent(Bool.self, forKey: .offlineMode) ?? false
        self.analyticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .analyticsEnabled) ?? false
        self.firstRunPrivacyChoiceCompleted = try container.decodeIfPresent(Bool.self, forKey: .firstRunPrivacyChoiceCompleted) ?? false
        self.selectedPrivacyProfile = try container.decodeIfPresent(PrivacyProfile.self, forKey: .selectedPrivacyProfile) ?? .maximumPrivacy
    }

    public static func settings(for profile: PrivacyProfile) -> PrivacySettings {
        switch profile {
        case .maximumPrivacy:
            return PrivacySettings(
                privacyMode: true,
                saveTranscriptHistory: false,
                saveLearningMemory: false,
                savePerformanceLogs: true,
                includeTargetAppInLogs: false,
                includeTargetBundleIdentifierInLogs: false,
                saveAudio: false,
                offlineMode: false,
                analyticsEnabled: false,
                firstRunPrivacyChoiceCompleted: true,
                selectedPrivacyProfile: profile
            )
        case .balancedLocalMemory:
            return PrivacySettings(
                privacyMode: false,
                saveTranscriptHistory: true,
                saveLearningMemory: true,
                savePerformanceLogs: true,
                includeTargetAppInLogs: false,
                includeTargetBundleIdentifierInLogs: false,
                saveAudio: false,
                offlineMode: false,
                analyticsEnabled: false,
                firstRunPrivacyChoiceCompleted: true,
                selectedPrivacyProfile: profile
            )
        case .debugMode:
            return PrivacySettings(
                privacyMode: false,
                saveTranscriptHistory: true,
                saveLearningMemory: true,
                savePerformanceLogs: true,
                includeTargetAppInLogs: true,
                includeTargetBundleIdentifierInLogs: true,
                saveAudio: false,
                offlineMode: false,
                analyticsEnabled: false,
                firstRunPrivacyChoiceCompleted: true,
                selectedPrivacyProfile: profile
            )
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var dictation: DictationSettings
    public var models: ModelSettings
    public var postProcessing: PostProcessingSettings
    public var privacy: PrivacySettings

    public init(
        dictation: DictationSettings = DictationSettings(),
        models: ModelSettings = ModelSettings(),
        postProcessing: PostProcessingSettings = PostProcessingSettings(),
        privacy: PrivacySettings = PrivacySettings()
    ) {
        self.dictation = dictation
        self.models = models
        self.postProcessing = postProcessing
        self.privacy = privacy
    }

    public static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case dictation
        case models
        case postProcessing
        case privacy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dictation = try container.decodeIfPresent(DictationSettings.self, forKey: .dictation) ?? DictationSettings()
        self.models = try container.decodeIfPresent(ModelSettings.self, forKey: .models) ?? ModelSettings()
        self.postProcessing = try container.decodeIfPresent(PostProcessingSettings.self, forKey: .postProcessing) ?? PostProcessingSettings()
        self.privacy = try container.decodeIfPresent(PrivacySettings.self, forKey: .privacy) ?? PrivacySettings()
    }
}

public enum NetworkAccessPolicy: Sendable {
    public static func canDownloadRemoteModel(privacy: PrivacySettings) -> Bool {
        !privacy.offlineMode
    }

    public static func canUseLocalModel(privacy: PrivacySettings) -> Bool {
        true
    }

    public static func canUseLocalhostService(privacy: PrivacySettings) -> Bool {
        true
    }
}
