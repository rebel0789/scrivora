import Foundation

public struct PrivacyExportOptions: Equatable, Sendable {
    public var name: String
    public var includeSettings: Bool
    public var includeHistory: Bool
    public var includeLearning: Bool
    public var includePerformanceLogs: Bool
    public var includeStorageSummary: Bool
    public var includeDebugSummary: Bool
    public var redactTranscriptText: Bool
    public var redactTargetMetadata: Bool
    public var redactLocalPaths: Bool

    public init(
        name: String,
        includeSettings: Bool = false,
        includeHistory: Bool = false,
        includeLearning: Bool = false,
        includePerformanceLogs: Bool = false,
        includeStorageSummary: Bool = false,
        includeDebugSummary: Bool = false,
        redactTranscriptText: Bool = true,
        redactTargetMetadata: Bool = true,
        redactLocalPaths: Bool = true
    ) {
        self.name = name
        self.includeSettings = includeSettings
        self.includeHistory = includeHistory
        self.includeLearning = includeLearning
        self.includePerformanceLogs = includePerformanceLogs
        self.includeStorageSummary = includeStorageSummary
        self.includeDebugSummary = includeDebugSummary
        self.redactTranscriptText = redactTranscriptText
        self.redactTargetMetadata = redactTargetMetadata
        self.redactLocalPaths = redactLocalPaths
    }

    public static let settingsOnly = PrivacyExportOptions(
        name: "settings",
        includeSettings: true,
        redactTranscriptText: true,
        redactTargetMetadata: true
    )

    public static let historyOnly = PrivacyExportOptions(
        name: "history",
        includeHistory: true,
        redactTranscriptText: false,
        redactTargetMetadata: false,
        redactLocalPaths: false
    )

    public static let learningOnly = PrivacyExportOptions(
        name: "learning",
        includeLearning: true,
        redactTranscriptText: false,
        redactTargetMetadata: false,
        redactLocalPaths: false
    )

    public static let performanceLogsOnly = PrivacyExportOptions(
        name: "performance-logs",
        includePerformanceLogs: true,
        redactTranscriptText: true,
        redactTargetMetadata: false,
        redactLocalPaths: true
    )

    public static let fullLocalPackage = PrivacyExportOptions(
        name: "full-local",
        includeSettings: true,
        includeHistory: true,
        includeLearning: true,
        includePerformanceLogs: true,
        includeStorageSummary: true,
        includeDebugSummary: true,
        redactTranscriptText: false,
        redactTargetMetadata: false,
        redactLocalPaths: false
    )

    public static let redactedDebugPackage = PrivacyExportOptions(
        name: "redacted-debug",
        includeSettings: true,
        includeHistory: true,
        includeLearning: true,
        includePerformanceLogs: true,
        includeStorageSummary: true,
        includeDebugSummary: true,
        redactTranscriptText: true,
        redactTargetMetadata: true,
        redactLocalPaths: true
    )
}

public struct PrivacyExportManifest: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var exportName: String
    public var redactedTranscriptText: Bool
    public var redactedTargetMetadata: Bool
    public var redactedLocalPaths: Bool
    public var files: [String]
}

public struct PrivacyExportResult: Equatable, Sendable {
    public var directory: URL
    public var manifest: PrivacyExportManifest
}

public struct StorageSummaryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var path: String
    public var byteCount: Int64
}

public struct DebugSummary: Codable, Equatable, Sendable {
    public var appName: String
    public var bundleIdentifier: String
    public var executableName: String
    public var selectedASRModelID: String
    public var selectedASRMode: String
    public var privacyMode: Bool
    public var saveTranscriptHistory: Bool
    public var saveLearningMemory: Bool
    public var savePerformanceLogs: Bool
    public var includeTargetAppInLogs: Bool
    public var includeTargetBundleIdentifierInLogs: Bool
    public var saveAudio: Bool
    public var offlineMode: Bool
}

public struct PrivacyExportService: Sendable {
    public var fileStore: LocalFileStore
    public var fluidAudioDirectory: URL?

    public init(
        fileStore: LocalFileStore = LocalFileStore(),
        fluidAudioDirectory: URL? = nil
    ) {
        self.fileStore = fileStore
        self.fluidAudioDirectory = fluidAudioDirectory
    }

    public func export(
        options: PrivacyExportOptions,
        to parentDirectory: URL,
        settings: AppSettings
    ) throws -> PrivacyExportResult {
        let exportDirectory = parentDirectory
            .appendingPathComponent("Scrivora-\(options.name)-export-\(Self.timestamp())", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        var files: [String] = []
        let encoder = Self.encoder()

        if options.includeSettings {
            var exportedSettings = settings
            if options.redactTargetMetadata {
                exportedSettings.privacy.includeTargetAppInLogs = false
                exportedSettings.privacy.includeTargetBundleIdentifierInLogs = false
            }
            if options.redactLocalPaths {
                exportedSettings.models.whisperExecutablePath = nil
                exportedSettings.models.customASRModelPath = nil
                exportedSettings.models.whisperServerExecutablePath = nil
            }
            try encoder.encode(exportedSettings)
                .write(to: exportDirectory.appendingPathComponent("settings.json"), options: [.atomic])
            files.append("settings.json")
        }

        if options.includeHistory {
            let records = (try? HistoryStore(directory: fileStore.historyDirectory).load()) ?? []
            let exported = records.map { record -> HistoryRecord in
                var metrics = record.latencyMetrics
                if options.redactTargetMetadata {
                    metrics.pasteTargetAppName = nil
                    metrics.pasteTargetBundleIdentifier = nil
                }
                return HistoryRecord(
                    id: record.id,
                    createdAt: record.createdAt,
                    finalTranscript: options.redactTranscriptText ? "[redacted]" : record.finalTranscript,
                    targetAppName: options.redactTargetMetadata ? nil : record.targetAppName,
                    asrModelID: record.asrModelID,
                    cleanupMode: record.cleanupMode,
                    outputProfile: record.outputProfile,
                    latencyMetrics: metrics
                )
            }
            try encoder.encode(exported)
                .write(to: exportDirectory.appendingPathComponent("history.json"), options: [.atomic])
            files.append("history.json")
        }

        if options.includeLearning {
            let records = (try? CorrectionStore(directory: fileStore.learningDirectory).load()) ?? []
            let exported = records.map { record in
                CorrectionRecord(
                    id: record.id,
                    createdAt: record.createdAt,
                    originalTranscript: options.redactTranscriptText ? "[redacted]" : record.originalTranscript,
                    correctedTranscript: options.redactTranscriptText ? "[redacted]" : record.correctedTranscript,
                    targetAppName: options.redactTargetMetadata ? nil : record.targetAppName,
                    asrModelID: record.asrModelID,
                    outputProfile: record.outputProfile,
                    learnedEntries: options.redactTranscriptText ? [] : record.learnedEntries
                )
            }
            try encoder.encode(exported)
                .write(to: exportDirectory.appendingPathComponent("learning-corrections.json"), options: [.atomic])
            files.append("learning-corrections.json")
        }

        if options.includePerformanceLogs {
            let outputName = options.redactTargetMetadata ? "performance-logs-redacted.jsonl" : "performance-logs.jsonl"
            try exportPerformanceLogs(
                to: exportDirectory.appendingPathComponent(outputName),
                options: options
            )
            files.append(outputName)
        }

        if options.includeStorageSummary {
            try encoder.encode(storageSummary(redactPaths: options.redactLocalPaths))
                .write(to: exportDirectory.appendingPathComponent("storage-summary.json"), options: [.atomic])
            files.append("storage-summary.json")
        }

        if options.includeDebugSummary {
            try encoder.encode(debugSummary(settings: settings))
                .write(to: exportDirectory.appendingPathComponent("debug-summary.json"), options: [.atomic])
            files.append("debug-summary.json")
        }

        let manifest = PrivacyExportManifest(
            generatedAt: Date(),
            exportName: options.name,
            redactedTranscriptText: options.redactTranscriptText,
            redactedTargetMetadata: options.redactTargetMetadata,
            redactedLocalPaths: options.redactLocalPaths,
            files: files.sorted()
        )
        try encoder.encode(manifest)
            .write(to: exportDirectory.appendingPathComponent("manifest.json"), options: [.atomic])

        return PrivacyExportResult(directory: exportDirectory, manifest: manifest)
    }

    private func exportPerformanceLogs(to outputURL: URL, options: PrivacyExportOptions) throws {
        let logURL = fileStore.logsDirectory.appendingPathComponent("dictation-performance.jsonl")
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            try Data().write(to: outputURL, options: [.atomic])
            return
        }

        let data = try Data(contentsOf: logURL)
        guard !data.isEmpty else {
            try Data().write(to: outputURL, options: [.atomic])
            return
        }

        let decoder = Self.decoder()
        let encoder = Self.lineEncoder()
        var output = Data()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true) {
            guard var record = try? decoder.decode(PerformanceLogRecord.self, from: Data(line.utf8)) else { continue }
            if options.redactTargetMetadata || options.redactLocalPaths {
                let tokens = [
                    record.targetAppName,
                    record.targetBundleIdentifier,
                    record.metrics.pasteTargetAppName,
                    record.metrics.pasteTargetBundleIdentifier
                ]
                record.error = Self.redactDiagnosticString(
                    record.error,
                    sensitiveTokens: tokens,
                    redactBundleIdentifiers: options.redactTargetMetadata,
                    redactLocalPaths: options.redactLocalPaths
                )
                record.metrics.pasteFailureReason = Self.redactDiagnosticString(
                    record.metrics.pasteFailureReason,
                    sensitiveTokens: tokens,
                    redactBundleIdentifiers: options.redactTargetMetadata,
                    redactLocalPaths: options.redactLocalPaths
                )
            }
            if options.redactTargetMetadata {
                record.targetAppName = nil
                record.targetBundleIdentifier = nil
                record.metrics.pasteTargetAppName = nil
                record.metrics.pasteTargetBundleIdentifier = nil
            }
            var encoded = try encoder.encode(record)
            encoded.append(0x0A)
            output.append(encoded)
        }
        try output.write(to: outputURL, options: [.atomic])
    }

    private static func redactDiagnosticString(
        _ value: String?,
        sensitiveTokens: [String?],
        redactBundleIdentifiers: Bool,
        redactLocalPaths: Bool
    ) -> String? {
        guard var redacted = value else { return nil }

        for token in sensitiveTokens.compactMap({ $0 }).filter({ !$0.isEmpty }) {
            redacted = redacted.replacingOccurrences(of: token, with: "[redacted]")
        }

        if redactLocalPaths {
            redacted = replacingMatches(
                in: redacted,
                pattern: #"(file://)?/(Users|Volumes|private|var|tmp)/[^\s"'<>]+"#,
                replacement: "[redacted-path]"
            )
            redacted = replacingMatches(
                in: redacted,
                pattern: #"~(/[^\s"'<>]+)+"#,
                replacement: "[redacted-path]"
            )
        }

        if redactBundleIdentifiers {
            redacted = replacingMatches(
                in: redacted,
                pattern: #"\b[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}\b"#,
                replacement: "[redacted-bundle-id]"
            )
        }

        return redacted
    }

    private static func replacingMatches(in value: String, pattern: String, replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(
            in: value,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }

    private func storageSummary(redactPaths: Bool) -> [StorageSummaryEntry] {
        var entries = [
            StorageSummaryEntry(id: "settings", path: exportPath(fileStore.settingsDirectory, redact: redactPaths), byteCount: byteCount(at: fileStore.settingsDirectory)),
            StorageSummaryEntry(id: "history", path: exportPath(fileStore.historyDirectory, redact: redactPaths), byteCount: byteCount(at: fileStore.historyDirectory)),
            StorageSummaryEntry(id: "learning", path: exportPath(fileStore.learningDirectory, redact: redactPaths), byteCount: byteCount(at: fileStore.learningDirectory)),
            StorageSummaryEntry(id: "logs", path: exportPath(fileStore.logsDirectory, redact: redactPaths), byteCount: byteCount(at: fileStore.logsDirectory)),
            StorageSummaryEntry(id: "whisper-models", path: exportPath(fileStore.modelsDirectory, redact: redactPaths), byteCount: byteCount(at: fileStore.modelsDirectory))
        ]
        if let fluidAudioDirectory {
            entries.append(StorageSummaryEntry(id: "fluidaudio-cache", path: exportPath(fluidAudioDirectory, redact: redactPaths), byteCount: byteCount(at: fluidAudioDirectory)))
        }
        return entries
    }

    private func exportPath(_ url: URL, redact: Bool) -> String {
        redact ? "[redacted]" : url.path
    }

    private func debugSummary(settings: AppSettings) -> DebugSummary {
        DebugSummary(
            appName: "Scrivora",
            bundleIdentifier: "me.scrivora.app",
            executableName: "LocalVoiceFlowApp",
            selectedASRModelID: settings.models.selectedASRModelID,
            selectedASRMode: settings.models.selectedASRMode.rawValue,
            privacyMode: settings.privacy.privacyMode,
            saveTranscriptHistory: settings.privacy.saveTranscriptHistory,
            saveLearningMemory: settings.privacy.saveLearningMemory,
            savePerformanceLogs: settings.privacy.savePerformanceLogs,
            includeTargetAppInLogs: settings.privacy.includeTargetAppInLogs,
            includeTargetBundleIdentifierInLogs: settings.privacy.includeTargetBundleIdentifierInLogs,
            saveAudio: settings.privacy.saveAudio,
            offlineMode: settings.privacy.offlineMode
        )
    }

    private func byteCount(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        if !isDirectory.boolValue { return fileByteCount(url) }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += fileByteCount(fileURL)
        }
        return total
    }

    private func fileByteCount(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
              values.isRegularFile == true
        else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func lineEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
