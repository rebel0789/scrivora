import Foundation

public struct TempAudioFileManager: Sendable {
    public var directory: URL
    public var prefix: String

    public init(
        directory: URL = FileManager.default.temporaryDirectory,
        prefix: String = "ScrivoraTempAudio"
    ) {
        self.directory = directory
        self.prefix = prefix
    }

    public func createTemporaryWAV(samples: [Float], sampleRate: Int = 16_000) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try WAVFileWriter.writeWAV(samples: samples, sampleRate: sampleRate, to: url)
        return url
    }

    public func removeTemporaryFile(_ url: URL) {
        guard isManagedTemporaryFile(url) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    public func removeStaleTemporaryFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var removed: [URL] = []
        for case let fileURL as URL in enumerator {
            guard isManagedTemporaryFile(fileURL) else { continue }
            try? FileManager.default.removeItem(at: fileURL)
            removed.append(fileURL)
        }
        return removed
    }

    public func isManagedTemporaryFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        return filename.hasPrefix("\(prefix)-")
            && ["wav", "txt"].contains(url.pathExtension.lowercased())
            && url.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path)
    }
}
