import CryptoKit
import Foundation
import LocalVoiceFlowCore

struct PreparedAppUpdate {
    var manifest: AppUpdateManifest
    var extractedAppURL: URL
    var workingDirectory: URL
}

struct AppUpdateInstaller {
    var installedAppURL: URL = URL(fileURLWithPath: AppBrand.installedAppPath, isDirectory: true)

    func fetchManifest(from url: URL) async throws -> AppUpdateManifest {
        let data: Data
        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            guard url.scheme?.lowercased() == "https" else {
                throw LocalVoiceFlowError.fileSystem("Update manifest must use HTTPS.")
            }
            let response: URLResponse
            (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LocalVoiceFlowError.fileSystem("Update manifest request failed with HTTP \(http.statusCode).")
            }
        }

        return try JSONDecoder().decode(AppUpdateManifest.self, from: data)
    }

    func prepareUpdate(
        _ manifest: AppUpdateManifest,
        expectedBundleIdentifier: String,
        currentVersion: String
    ) async throws -> PreparedAppUpdate {
        guard manifest.appID == expectedBundleIdentifier else {
            throw LocalVoiceFlowError.fileSystem("Update is for \(manifest.appID), not \(expectedBundleIdentifier).")
        }
        guard AppUpdateVersionComparator.isVersion(manifest.version, newerThan: currentVersion) else {
            throw LocalVoiceFlowError.fileSystem("Update \(manifest.version) is not newer than \(currentVersion).")
        }

        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrivoraUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        do {
            let archiveURL = try await downloadArchive(manifest.downloadURL, to: workingDirectory)
            try verifySHA256(archiveURL, expected: manifest.sha256)
            let extractedApp = try await extractArchive(archiveURL, into: workingDirectory)
            try await validateAppBundle(
                extractedApp,
                expectedBundleIdentifier: expectedBundleIdentifier,
                expectedVersion: manifest.version
            )
            return PreparedAppUpdate(
                manifest: manifest,
                extractedAppURL: extractedApp,
                workingDirectory: workingDirectory
            )
        } catch {
            try? FileManager.default.removeItem(at: workingDirectory)
            throw error
        }
    }

    func launchInstaller(for prepared: PreparedAppUpdate) throws {
        guard installedAppURL.path == AppBrand.installedAppPath else {
            throw LocalVoiceFlowError.fileSystem("Unexpected install destination: \(installedAppURL.path)")
        }

        let scriptURL = prepared.workingDirectory.appendingPathComponent("install-update.zsh")
        let logURL = prepared.workingDirectory.appendingPathComponent("install-update.log")
        let script = """
        #!/bin/zsh
        set -euo pipefail
        SOURCE_APP="$1"
        DEST_APP="$2"
        WORK_DIR="$3"
        LOG_FILE="$4"
        {
          sleep 1
          if [[ -d "$DEST_APP" ]]; then
            rm -rf "$DEST_APP"
          fi
          /usr/bin/ditto "$SOURCE_APP" "$DEST_APP"
          /usr/bin/open "$DEST_APP"
          rm -rf "$WORK_DIR"
        } >> "$LOG_FILE" 2>&1
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            scriptURL.path,
            prepared.extractedAppURL.path,
            installedAppURL.path,
            prepared.workingDirectory.path,
            logURL.path
        ]
        try process.run()
    }

    private func downloadArchive(_ url: URL, to directory: URL) async throws -> URL {
        let destination = directory.appendingPathComponent(url.lastPathComponent.isEmpty ? "Scrivora-update.zip" : url.lastPathComponent)

        if url.isFileURL {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        }

        guard url.scheme?.lowercased() == "https" else {
            throw LocalVoiceFlowError.fileSystem("Update download must use HTTPS.")
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LocalVoiceFlowError.fileSystem("Update download failed with HTTP \(http.statusCode).")
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func verifySHA256(_ url: URL, expected: String) throws {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        let normalizedExpected = expected
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard actual == normalizedExpected else {
            throw LocalVoiceFlowError.fileSystem("Update SHA-256 mismatch. Expected \(normalizedExpected), got \(actual).")
        }
    }

    private func extractArchive(_ archiveURL: URL, into directory: URL) async throws -> URL {
        let outputDirectory = directory.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        _ = try await ProcessRunner.run(
            executable: "/usr/bin/ditto",
            arguments: ["-x", "-k", archiveURL.path, outputDirectory.path]
        )

        let direct = outputDirectory.appendingPathComponent("Scrivora.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        if let app = contents.first(where: { $0.pathExtension == "app" }) {
            return app
        }

        throw LocalVoiceFlowError.fileSystem("Update archive did not contain a .app bundle.")
    }

    private func validateAppBundle(
        _ appURL: URL,
        expectedBundleIdentifier: String,
        expectedVersion: String
    ) async throws {
        guard let expectedTeamID = AppBrand.updateDeveloperTeamIdentifier,
              !expectedTeamID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw LocalVoiceFlowError.fileSystem("In-app updates require a configured Developer ID Team ID.")
        }

        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard
            let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
            let bundleIdentifier = info["CFBundleIdentifier"] as? String,
            let version = info["CFBundleShortVersionString"] as? String
        else {
            throw LocalVoiceFlowError.fileSystem("Update app is missing bundle metadata.")
        }
        guard bundleIdentifier == expectedBundleIdentifier else {
            throw LocalVoiceFlowError.fileSystem("Update bundle ID \(bundleIdentifier) does not match \(expectedBundleIdentifier).")
        }
        guard version == expectedVersion else {
            throw LocalVoiceFlowError.fileSystem("Update version \(version) does not match manifest \(expectedVersion).")
        }

        _ = try await ProcessRunner.run(
            executable: "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", appURL.path]
        )
        let signingDetails = try await ProcessRunner.run(
            executable: "/usr/bin/codesign",
            arguments: ["-dv", "--verbose=4", appURL.path]
        )
        let details = signingDetails.combined
        guard details.contains("TeamIdentifier=\(expectedTeamID)") else {
            throw LocalVoiceFlowError.fileSystem("Update signer does not match Scrivora Developer ID Team ID.")
        }
        guard !details.contains("Signature=adhoc") else {
            throw LocalVoiceFlowError.fileSystem("Update is ad-hoc signed and cannot be installed by the in-app updater.")
        }

        _ = try await ProcessRunner.run(
            executable: "/usr/sbin/spctl",
            arguments: ["--assess", "--type", "execute", appURL.path]
        )
    }
}
