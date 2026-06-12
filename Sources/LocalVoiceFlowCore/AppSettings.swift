import Foundation

public enum DictationMode: String, Codable, CaseIterable, Sendable {
    case toggle
    case pushToTalk
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

public enum ASRUserMode: String, Codable, CaseIterable, Sendable {
    case instant
    case balanced
    case accurate
    case highestQuality
    case experimental
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
    public var mode: DictationMode
    public var autoStopOnSilence: Bool
    public var silenceDurationMilliseconds: Int
    public var startStopSound: Bool
    public var showFloatingOverlay: Bool
    public var autoPaste: Bool
    public var copyToClipboard: Bool
    public var restoreClipboardAfterPaste: Bool
    public var longDictationMode: Bool
    public var selectedInputDeviceID: String?

    public init(
        shortcut: GlobalShortcut = .default,
        mode: DictationMode = .toggle,
        autoStopOnSilence: Bool = true,
        silenceDurationMilliseconds: Int = 700,
        startStopSound: Bool = true,
        showFloatingOverlay: Bool = true,
        autoPaste: Bool = true,
        copyToClipboard: Bool = true,
        restoreClipboardAfterPaste: Bool = true,
        longDictationMode: Bool = false,
        selectedInputDeviceID: String? = nil
    ) {
        self.shortcut = shortcut
        self.mode = mode
        self.autoStopOnSilence = autoStopOnSilence
        self.silenceDurationMilliseconds = silenceDurationMilliseconds
        self.startStopSound = startStopSound
        self.showFloatingOverlay = showFloatingOverlay
        self.autoPaste = autoPaste
        self.copyToClipboard = copyToClipboard
        self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
        self.longDictationMode = longDictationMode
        self.selectedInputDeviceID = selectedInputDeviceID
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
        selectedASRModelID: String = ModelCatalog.default.recommendedModel(for: .balanced)?.id ?? "whispercpp-base-en-q5",
        selectedLLMModelID: String? = nil,
        selectedASRMode: ASRUserMode = .balanced,
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
}

public struct PostProcessingSettings: Codable, Equatable, Sendable {
    public var cleanupMode: CleanupMode
    public var preset: PostProcessingPreset
    public var customPrompt: String
    public var customReplacements: [CustomReplacement]
    public var userDictionary: [UserDictionaryEntry]

    public init(
        cleanupMode: CleanupMode = .fast,
        preset: PostProcessingPreset = .cleanPunctuation,
        customPrompt: String = "",
        customReplacements: [CustomReplacement] = CustomReplacement.defaults,
        userDictionary: [UserDictionaryEntry] = []
    ) {
        self.cleanupMode = cleanupMode
        self.preset = preset
        self.customPrompt = customPrompt
        self.customReplacements = customReplacements
        self.userDictionary = userDictionary
    }
}

public struct PrivacySettings: Codable, Equatable, Sendable {
    public var privacyMode: Bool
    public var saveTranscriptHistory: Bool
    public var saveAudio: Bool
    public var offlineMode: Bool
    public var analyticsEnabled: Bool

    public init(
        privacyMode: Bool = false,
        saveTranscriptHistory: Bool = true,
        saveAudio: Bool = false,
        offlineMode: Bool = false,
        analyticsEnabled: Bool = false
    ) {
        self.privacyMode = privacyMode
        self.saveTranscriptHistory = saveTranscriptHistory
        self.saveAudio = saveAudio
        self.offlineMode = offlineMode
        self.analyticsEnabled = analyticsEnabled
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
}
