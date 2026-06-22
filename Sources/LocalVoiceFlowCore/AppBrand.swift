import Foundation

public enum AppBrand {
    public static let productName = "Scrivora"
    public static let tagline = "Local dictation for Mac."
    public static let shortDescription = "Private dictation that runs on your Mac."
    public static let privacyDescription = "Your voice stays on your Mac. Core dictation does not use a cloud speech API."
    public static let localFirstDescription = "Scrivora records speech, transcribes locally, and inserts text into the focused app."

    public static let legacyProductName = "LocalVoiceFlow"
    public static let bundleIdentifier = "me.scrivora.app"
    public static let websiteURL = "https://scrivora.me"
    public static let updateManifestURL = "https://scrivora.me/updates/stable.json"
    public static let signingIdentity = "LocalVoiceFlow Development"
    public static let installedAppPath = "/Applications/Scrivora.app"

    public static var updateDeveloperTeamIdentifier: String? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "ScrivoraUpdateDeveloperTeamID") as? String
        else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
