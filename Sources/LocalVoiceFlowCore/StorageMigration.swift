import Foundation

public struct DataStorageMigrationStatus: Equatable, Sendable {
    public var currentRootPath: String
    public var legacyRootPath: String
    public var scrivoraRootPath: String
    public var usingLegacyRoot: Bool
    public var legacyRootExists: Bool
    public var scrivoraRootExists: Bool
}

public struct DataStorageMigrationService: Sendable {
    public init() {}

    public func status(currentRootDirectory: URL) -> DataStorageMigrationStatus {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let legacyRoot = appSupport.appendingPathComponent("LocalVoiceFlow", isDirectory: true)
        let scrivoraRoot = appSupport.appendingPathComponent("Scrivora", isDirectory: true)

        return DataStorageMigrationStatus(
            currentRootPath: currentRootDirectory.path,
            legacyRootPath: legacyRoot.path,
            scrivoraRootPath: scrivoraRoot.path,
            usingLegacyRoot: currentRootDirectory.standardizedFileURL.path == legacyRoot.standardizedFileURL.path,
            legacyRootExists: FileManager.default.fileExists(atPath: legacyRoot.path),
            scrivoraRootExists: FileManager.default.fileExists(atPath: scrivoraRoot.path)
        )
    }
}
