import Foundation

public enum ASRBackend: String, Codable, CaseIterable, Sendable {
    case whisperKit
    case whisperCpp
    case fluidAudio
    case sherpaOnnx
    case moonshine
    case mock
}

public struct AudioBuffer: Equatable, Sendable {
    public var samples: [Float]
    public var sampleRate: Int

    public init(samples: [Float], sampleRate: Int = 16_000) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var durationSeconds: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / Double(sampleRate)
    }
}

public struct AudioChunk: Identifiable, Equatable, Sendable {
    public var id: Int
    public var samples: [Float]
    public var sampleRate: Int
    public var startSample: Int
    public var sequenceNumber: Int

    public init(
        id: Int,
        samples: [Float],
        sampleRate: Int,
        startSample: Int,
        sequenceNumber: Int
    ) {
        self.id = id
        self.samples = samples
        self.sampleRate = sampleRate
        self.startSample = startSample
        self.sequenceNumber = sequenceNumber
    }

    public var durationSeconds: Double {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / Double(sampleRate)
    }
}

public struct ASRModelInfo: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var mode: ASRUserMode
    public var displayName: String
    public var backend: ASRBackend
    public var engineIdentifier: String
    public var localFilename: String
    public var downloadURL: URL?
    public var estimatedSizeMB: Int
    public var estimatedMemoryMB: Int
    public var speedLabel: String
    public var qualityLabel: String
    public var license: String

    public init(
        id: String,
        mode: ASRUserMode,
        displayName: String,
        backend: ASRBackend,
        engineIdentifier: String,
        localFilename: String,
        downloadURL: URL?,
        estimatedSizeMB: Int,
        estimatedMemoryMB: Int,
        speedLabel: String,
        qualityLabel: String,
        license: String
    ) {
        self.id = id
        self.mode = mode
        self.displayName = displayName
        self.backend = backend
        self.engineIdentifier = engineIdentifier
        self.localFilename = localFilename
        self.downloadURL = downloadURL
        self.estimatedSizeMB = estimatedSizeMB
        self.estimatedMemoryMB = estimatedMemoryMB
        self.speedLabel = speedLabel
        self.qualityLabel = qualityLabel
        self.license = license
    }
}

public struct ASRPartialResult: Equatable, Sendable {
    public var text: String
    public var stableText: String
    public var unstableText: String
    public var chunkID: Int
    public var isStable: Bool

    public init(
        text: String,
        stableText: String = "",
        unstableText: String = "",
        chunkID: Int,
        isStable: Bool
    ) {
        self.text = text
        self.stableText = stableText
        self.unstableText = unstableText
        self.chunkID = chunkID
        self.isStable = isStable
    }
}

public struct ASRResult: Equatable, Sendable {
    public var text: String
    public var segments: [String]
    public var latency: TimeInterval
    public var modelID: String

    public init(text: String, segments: [String] = [], latency: TimeInterval = 0, modelID: String = "") {
        self.text = text
        self.segments = segments
        self.latency = latency
        self.modelID = modelID
    }
}

public protocol ASREngine: Sendable {
    var isLoaded: Bool { get async }
    var modelInfo: ASRModelInfo? { get async }

    func loadModel(_ model: ASRModelInfo) async throws
    func warmup() async throws
    func transcribe(chunk: AudioChunk) async throws -> ASRPartialResult
    func transcribeFinal(buffer: AudioBuffer) async throws -> ASRResult
    func unload() async
}

public protocol StreamingASREngine: Sendable {
    var isLoaded: Bool { get async }
    var modelInfo: ASRModelInfo? { get async }

    func loadModel(_ model: ASRModelInfo) async throws
    func warmup() async throws
    func startSession() async throws
    func acceptAudioFrame(_ frame: AudioChunk) async throws
    func getPartialResult() async throws -> ASRPartialResult?
    func finishSession() async throws -> ASRResult
    func resetSession() async
}
