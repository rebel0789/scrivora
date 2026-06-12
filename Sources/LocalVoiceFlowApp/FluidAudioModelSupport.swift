import Foundation
import FluidAudio
import LocalVoiceFlowCore

enum FluidAudioModelSupport {
    static func version(for model: ASRModelInfo) throws -> AsrModelVersion {
        switch model.engineIdentifier {
        case "parakeet-tdt-0.6b-v3":
            return .v3
        case "parakeet-tdt-0.6b-v2":
            return .v2
        default:
            throw LocalVoiceFlowError.modelUnavailable("Unsupported FluidAudio model: \(model.engineIdentifier).")
        }
    }

    static func cacheDirectory(for model: ASRModelInfo) throws -> URL {
        AsrModels.defaultCacheDirectory(for: try version(for: model))
    }

    static func isDownloaded(_ model: ASRModelInfo) -> Bool {
        guard let version = try? version(for: model) else { return false }
        let directory = AsrModels.defaultCacheDirectory(for: version)
        return AsrModels.modelsExist(at: directory, version: version)
    }

    @discardableResult
    static func download(_ model: ASRModelInfo) async throws -> URL {
        let version = try version(for: model)
        try removeIncompleteCacheIfNeeded(for: version)
        return try await AsrModels.download(version: version)
    }

    static func delete(_ model: ASRModelInfo) throws {
        let directory = try cacheDirectory(for: model)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private static func removeIncompleteCacheIfNeeded(for version: AsrModelVersion) throws {
        let directory = AsrModels.defaultCacheDirectory(for: version)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directory.path) else { return }
        guard !AsrModels.modelsExist(at: directory, version: version) else { return }

        try fileManager.removeItem(at: directory)
    }
}
