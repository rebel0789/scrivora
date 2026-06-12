import Foundation

public struct ForegroundAppInfo: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var localizedName: String?

    public init(bundleIdentifier: String?, localizedName: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
    }
}

public struct ResolvedDictationProfile: Equatable, Sendable {
    public var profile: DictationOutputProfile
    public var targetAppName: String?
    public var targetBundleIdentifier: String?
    public var category: String
    public var reason: String

    public init(
        profile: DictationOutputProfile,
        targetAppName: String? = nil,
        targetBundleIdentifier: String? = nil,
        category: String,
        reason: String
    ) {
        self.profile = profile
        self.targetAppName = targetAppName
        self.targetBundleIdentifier = targetBundleIdentifier
        self.category = category
        self.reason = reason
    }

    public static let fallback = ResolvedDictationProfile(
        profile: .general,
        category: "unknown",
        reason: "No target app was available."
    )
}

public struct AppProfileResolver: Sendable {
    private let codingBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp",
        "co.zeit.hyper"
    ]

    private let agentBundleIDs: Set<String> = [
        "com.openai.chat",
        "com.anthropic.claudefordesktop",
        "com.openai.codex"
    ]

    private let emailBundleIDs: Set<String> = [
        "com.apple.mail",
        "com.microsoft.Outlook",
        "com.readdle.smartemail-Mac",
        "com.superhuman.mail"
    ]

    private let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "org.mozilla.firefox"
    ]

    public init() {}

    public func resolve(
        app: ForegroundAppInfo?,
        settings: PostProcessingSettings
    ) -> ResolvedDictationProfile {
        let override = settings.outputProfile
        if override != .automatic {
            return ResolvedDictationProfile(
                profile: override == .raw ? .raw : override,
                targetAppName: app?.localizedName,
                targetBundleIdentifier: app?.bundleIdentifier,
                category: "manual",
                reason: "Manual output profile override."
            )
        }

        guard let app else { return .fallback }

        let bundleID = app.bundleIdentifier ?? ""
        let name = app.localizedName ?? ""

        if codingBundleIDs.contains(bundleID) || nameMatches(name, [
            "Xcode",
            "Visual Studio Code",
            "Code",
            "Cursor",
            "Terminal",
            "iTerm",
            "iTerm2",
            "Warp",
            "Hyper"
        ]) {
            return resolved(.pragmatic, app: app, category: "coding", reason: "Coding or terminal app detected.")
        }

        if agentBundleIDs.contains(bundleID) || nameMatches(name, [
            "ChatGPT",
            "Claude",
            "Codex",
            "Gemini",
            "Perplexity",
            "LM Studio",
            "Ollama"
        ]) {
            return resolved(.agent, app: app, category: "agent", reason: "AI agent or chat app detected.")
        }

        if emailBundleIDs.contains(bundleID) || nameMatches(name, [
            "Mail",
            "Microsoft Outlook",
            "Outlook",
            "Spark",
            "Superhuman"
        ]) {
            return resolved(.email, app: app, category: "email", reason: "Email app detected.")
        }

        if nameMatches(name, [
            "Notes",
            "TextEdit",
            "Pages",
            "Notion",
            "Slack",
            "Discord"
        ]) {
            return resolved(.general, app: app, category: "writing", reason: "Writing or messaging app detected.")
        }

        if browserBundleIDs.contains(bundleID) {
            return resolved(.general, app: app, category: "browser", reason: "Browser detected; tab-specific routing is not enabled.")
        }

        return resolved(.general, app: app, category: "general", reason: "Default local cleanup profile.")
    }

    private func resolved(
        _ profile: DictationOutputProfile,
        app: ForegroundAppInfo,
        category: String,
        reason: String
    ) -> ResolvedDictationProfile {
        ResolvedDictationProfile(
            profile: profile,
            targetAppName: app.localizedName,
            targetBundleIdentifier: app.bundleIdentifier,
            category: category,
            reason: reason
        )
    }

    private func nameMatches(_ name: String, _ candidates: [String]) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return candidates.contains { candidate in
            normalizedName == candidate.lowercased()
        }
    }
}
