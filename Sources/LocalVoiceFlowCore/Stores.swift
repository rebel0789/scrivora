import Foundation

public struct LocalFileStore: Sendable {
    public var rootDirectory: URL

    public init(rootDirectory: URL = LocalFileStore.defaultRootDirectory()) {
        self.rootDirectory = rootDirectory
    }

    public var settingsDirectory: URL { rootDirectory.appendingPathComponent("Settings", isDirectory: true) }
    public var modelsDirectory: URL { rootDirectory.appendingPathComponent("Models", isDirectory: true) }
    public var historyDirectory: URL { rootDirectory.appendingPathComponent("History", isDirectory: true) }
    public var logsDirectory: URL { rootDirectory.appendingPathComponent("Logs", isDirectory: true) }
    public var learningDirectory: URL { rootDirectory.appendingPathComponent("Learning", isDirectory: true) }

    public func prepareDirectories() throws {
        for directory in [rootDirectory, settingsDirectory, modelsDirectory, historyDirectory, logsDirectory, learningDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    public static func defaultRootDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("LocalVoiceFlow", isDirectory: true)
    }
}

public struct SettingsStore: Sendable {
    public var directory: URL
    private var fileURL: URL { directory.appendingPathComponent("settings.json") }

    public init(directory: URL = LocalFileStore().settingsDirectory) {
        self.directory = directory
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .default
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.localVoiceFlow.decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.localVoiceFlow.encode(settings)
        try data.write(to: fileURL, options: [.atomic])
    }
}

public struct HistoryRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var finalTranscript: String
    public var targetAppName: String?
    public var asrModelID: String
    public var cleanupMode: CleanupMode
    public var outputProfile: String?
    public var latencyMetrics: LatencyMetrics

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        finalTranscript: String,
        targetAppName: String?,
        asrModelID: String,
        cleanupMode: CleanupMode,
        outputProfile: String? = nil,
        latencyMetrics: LatencyMetrics
    ) {
        self.id = id
        self.createdAt = createdAt
        self.finalTranscript = finalTranscript
        self.targetAppName = targetAppName
        self.asrModelID = asrModelID
        self.cleanupMode = cleanupMode
        self.outputProfile = outputProfile
        self.latencyMetrics = latencyMetrics
    }
}

public struct HistoryStore: Sendable {
    public var directory: URL
    private var fileURL: URL { directory.appendingPathComponent("history.json") }

    public init(directory: URL = LocalFileStore().historyDirectory) {
        self.directory = directory
    }

    public func load() throws -> [HistoryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.localVoiceFlow.decode([HistoryRecord].self, from: data)
    }

    public func append(_ record: HistoryRecord, respecting privacy: PrivacySettings) throws {
        guard privacy.saveTranscriptHistory, !privacy.privacyMode else { return }
        var records = try load()
        records.insert(record, at: 0)
        try save(records)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func save(_ records: [HistoryRecord]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.localVoiceFlow.encode(records)
        try data.write(to: fileURL, options: [.atomic])
    }
}

public struct PerformanceLogRecord: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var triggerMode: String
    public var asrBackend: String
    public var modelID: String
    public var outputProfile: String
    public var targetAppName: String?
    public var targetBundleIdentifier: String?
    public var streamingMode: String
    public var durationRecorded: TimeInterval
    public var metrics: LatencyMetrics
    public var pasteMethod: String?
    public var error: String?

    public init(
        timestamp: Date = Date(),
        triggerMode: String,
        asrBackend: String,
        modelID: String,
        outputProfile: String,
        targetAppName: String?,
        targetBundleIdentifier: String?,
        streamingMode: String,
        durationRecorded: TimeInterval,
        metrics: LatencyMetrics,
        pasteMethod: String?,
        error: String?
    ) {
        self.timestamp = timestamp
        self.triggerMode = triggerMode
        self.asrBackend = asrBackend
        self.modelID = modelID
        self.outputProfile = outputProfile
        self.targetAppName = targetAppName
        self.targetBundleIdentifier = targetBundleIdentifier
        self.streamingMode = streamingMode
        self.durationRecorded = durationRecorded
        self.metrics = metrics
        self.pasteMethod = pasteMethod
        self.error = error
    }
}

public struct PerformanceLogStore: Sendable {
    public var directory: URL
    private var fileURL: URL { directory.appendingPathComponent("dictation-performance.jsonl") }

    public init(directory: URL = LocalFileStore().logsDirectory) {
        self.directory = directory
    }

    public func append(_ record: PerformanceLogRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.localVoiceFlowLine.encode(record)
        var line = data
        line.append(0x0A)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
            try handle.close()
        } else {
            try line.write(to: fileURL, options: [.atomic])
        }
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

public struct CorrectionRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var originalTranscript: String
    public var correctedTranscript: String
    public var targetAppName: String?
    public var asrModelID: String?
    public var outputProfile: String?
    public var learnedEntries: [UserDictionaryEntry]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        originalTranscript: String,
        correctedTranscript: String,
        targetAppName: String?,
        asrModelID: String?,
        outputProfile: String?,
        learnedEntries: [UserDictionaryEntry]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.originalTranscript = originalTranscript
        self.correctedTranscript = correctedTranscript
        self.targetAppName = targetAppName
        self.asrModelID = asrModelID
        self.outputProfile = outputProfile
        self.learnedEntries = learnedEntries
    }
}

public struct ImprovementStats: Equatable, Sendable {
    public var correctionCount: Int
    public var learnedEntryCount: Int
    public var latestCorrectionAt: Date?

    public init(
        correctionCount: Int = 0,
        learnedEntryCount: Int = 0,
        latestCorrectionAt: Date? = nil
    ) {
        self.correctionCount = correctionCount
        self.learnedEntryCount = learnedEntryCount
        self.latestCorrectionAt = latestCorrectionAt
    }
}

public struct CorrectionStore: Sendable {
    public var directory: URL
    private var fileURL: URL { directory.appendingPathComponent("corrections.json") }

    public init(directory: URL = LocalFileStore().learningDirectory) {
        self.directory = directory
    }

    public func load() throws -> [CorrectionRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.localVoiceFlow.decode([CorrectionRecord].self, from: data)
    }

    public func append(_ record: CorrectionRecord) throws {
        var records = try load()
        records.insert(record, at: 0)
        try save(records)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    public func stats() throws -> ImprovementStats {
        let records = try load()
        return ImprovementStats(
            correctionCount: records.count,
            learnedEntryCount: records.flatMap(\.learnedEntries).count,
            latestCorrectionAt: records.first?.createdAt
        )
    }

    private func save(_ records: [CorrectionRecord]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.localVoiceFlow.encode(records)
        try data.write(to: fileURL, options: [.atomic])
    }
}

public struct ModelStorage: Sendable {
    public var directory: URL

    public init(directory: URL = LocalFileStore().modelsDirectory) {
        self.directory = directory
    }

    public func localURL(for model: ASRModelInfo) -> URL {
        directory.appendingPathComponent(model.localFilename)
    }

    public func localURL(for model: ASRModelInfo, overridePath: String?) -> URL {
        if let overridePath, !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: overridePath)
        }
        return localURL(for: model)
    }

    public func isDownloaded(_ model: ASRModelInfo) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: model).path)
    }

    public func delete(_ model: ASRModelInfo) throws {
        let url = localURL(for: model)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

public struct ModelDownloader: Sendable {
    public init() {}

    public func download(model: ASRModelInfo, to storage: ModelStorage) async throws -> URL {
        guard let url = model.downloadURL else {
            throw LocalVoiceFlowError.modelUnavailable("No download URL for \(model.displayName).")
        }
        try FileManager.default.createDirectory(at: storage.directory, withIntermediateDirectories: true)
        let destination = storage.localURL(for: model)
        let (temporaryURL, _) = try await URLSession.shared.download(from: url)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }
}

private extension JSONEncoder {
    static var localVoiceFlow: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var localVoiceFlowLine: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var localVoiceFlow: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
