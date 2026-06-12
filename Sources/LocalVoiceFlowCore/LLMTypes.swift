import Foundation

public struct LLMModelInfo: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var engineIdentifier: String
    public var localFilename: String
    public var estimatedSizeMB: Int
    public var estimatedMemoryMB: Int
    public var license: String

    public init(
        id: String,
        displayName: String,
        engineIdentifier: String,
        localFilename: String,
        estimatedSizeMB: Int,
        estimatedMemoryMB: Int,
        license: String
    ) {
        self.id = id
        self.displayName = displayName
        self.engineIdentifier = engineIdentifier
        self.localFilename = localFilename
        self.estimatedSizeMB = estimatedSizeMB
        self.estimatedMemoryMB = estimatedMemoryMB
        self.license = license
    }
}

public struct LLMPromptTemplate: Codable, Equatable, Sendable {
    public var preset: PostProcessingPreset
    public var prompt: String

    public init(preset: PostProcessingPreset, prompt: String) {
        self.preset = preset
        self.prompt = prompt
    }

    public static let transcriptCleanup = LLMPromptTemplate(
        preset: .cleanPunctuation,
        prompt: """
        You are a local transcript cleanup engine.
        Fix punctuation, capitalization, spacing, and obvious speech-to-text formatting issues.
        Preserve the speaker's meaning exactly.
        Do not add facts.
        Do not remove important details.
        Do not summarize.
        Do not explain your changes.
        Return only the corrected text.
        """
    )
}

public protocol LLMEngine: Sendable {
    var isLoaded: Bool { get async }
    var modelInfo: LLMModelInfo? { get async }

    func loadModel(_ model: LLMModelInfo) async throws
    func warmup() async throws
    func process(prompt: String, inputText: String) async throws -> String
    func unload() async
}

