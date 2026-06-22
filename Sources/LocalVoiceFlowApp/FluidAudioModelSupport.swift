import CryptoKit
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
        guard AsrModels.modelsExist(at: directory, version: version) else { return false }
        return (try? verifyCacheIntegrity(at: directory, version: version)) != nil
    }

    @discardableResult
    static func download(
        _ model: ASRModelInfo,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let version = try version(for: model)
        progress?(0.04)
        try removeIncompleteCacheIfNeeded(for: version)
        progress?(0.08)
        let directory = try await download(version: version, force: false, progress: progress)
        do {
            progress?(0.90)
            try verifyCacheIntegrity(at: directory, version: version) { completed, total in
                guard total > 0 else { return }
                progress?(0.90 + (Double(completed) / Double(total)) * 0.08)
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            progress?(0.12)
            let redownloadedDirectory = try await download(version: version, force: true, progress: progress)
            progress?(0.90)
            try verifyCacheIntegrity(at: redownloadedDirectory, version: version) { completed, total in
                guard total > 0 else { return }
                progress?(0.90 + (Double(completed) / Double(total)) * 0.08)
            }
            progress?(1.0)
            return redownloadedDirectory
        }
        progress?(1.0)
        return directory
    }

    private static func download(
        version: AsrModelVersion,
        force: Bool,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        try await AsrModels.download(force: force, version: version) { snapshot in
            let clamped = min(1, max(0, snapshot.fractionCompleted))
            progress?(0.10 + clamped * 0.78)
        }
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

    private static func verifyCacheIntegrity(
        at directory: URL,
        version: AsrModelVersion,
        progress: ((_ completed: Int, _ total: Int) -> Void)? = nil
    ) throws {
        let hashes = pinnedHashes(for: version).sorted { $0.key < $1.key }
        for (index, entry) in hashes.enumerated() {
            let (relativePath, expectedSHA256) = entry
            let url = directory.appendingPathComponent(relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw LocalVoiceFlowError.modelUnavailable("FluidAudio model cache is missing \(relativePath).")
            }
            let actual = try sha256Hex(of: url)
            guard actual == expectedSHA256 else {
                throw LocalVoiceFlowError.modelUnavailable("FluidAudio model cache failed integrity check for \(relativePath).")
            }
            progress?(index + 1, hashes.count)
        }
    }

    private static func pinnedHashes(for version: AsrModelVersion) -> [String: String] {
        switch version {
        case .v2:
            return [
                "Preprocessor.mlmodelc/coremldata.bin": "d88ea1fc349459c9e100d6a96688c5b29a1f0d865f544be103001724b986b6d6",
                "Encoder.mlmodelc/coremldata.bin": "4def7aa848599ad0e17a8b9a982edcdbf33cf92e1f4b798de32e2ca0bc74b030",
                "Decoder.mlmodelc/coremldata.bin": "d200ca07694a347f6d02a3886a062ae839831e094e443222f2e48a14945966a8",
                "JointDecision.mlmodelc/coremldata.bin": "e2c6752f1c8cf2d3f6f26ec93195c9bfa759ad59edf9f806696a138154f96f11",
                "parakeet_vocab.json": "57019fe3c745772ca83a1b048a4bb951cd51329504ea33d4d83316b96e279a97"
            ]
        case .v3:
            return [
                "Preprocessor.mlmodelc/coremldata.bin": "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d",
                "Encoder.mlmodelc/coremldata.bin": "d48034a167a82e88fc3df64f60af963ab3983538271175b8319e7d5720a0fb86",
                "Decoder.mlmodelc/coremldata.bin": "18647af085d87bd8f3121c8a9b4d4564c1ede038dab63d295b4e745cf2d7fb99",
                "JointDecisionv3.mlmodelc/coremldata.bin": "f5fc08b741400f0088492c9e839418b1e18522f19cba28d361dd030c5f398342",
                "parakeet_vocab.json": "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735",
                "parakeet_v3_vocab.json": "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"
            ]
        default:
            return [:]
        }
    }

    private static func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
