import Testing
@testable import LocalVoiceFlowCore

struct AppProfileResolverTests {
    @Test func codingAppsUsePragmaticProfile() {
        let resolver = AppProfileResolver()

        let result = resolver.resolve(
            app: ForegroundAppInfo(bundleIdentifier: "com.microsoft.VSCode", localizedName: "Visual Studio Code"),
            settings: .init()
        )

        #expect(result.profile == .pragmatic)
        #expect(result.category == "coding")
    }

    @Test func cursorNameUsesPragmaticProfileEvenWhenBundleIDIsUnknown() {
        let resolver = AppProfileResolver()

        let result = resolver.resolve(
            app: ForegroundAppInfo(bundleIdentifier: "unknown.cursor.bundle", localizedName: "Cursor"),
            settings: .init()
        )

        #expect(result.profile == .pragmatic)
    }

    @Test func agentAppsUseAgentProfile() {
        let resolver = AppProfileResolver()

        let result = resolver.resolve(
            app: ForegroundAppInfo(bundleIdentifier: "com.openai.chat", localizedName: "ChatGPT"),
            settings: .init()
        )

        #expect(result.profile == .agent)
        #expect(result.category == "agent")
    }

    @Test func emailAppsUseEmailProfile() {
        let resolver = AppProfileResolver()

        let result = resolver.resolve(
            app: ForegroundAppInfo(bundleIdentifier: "com.apple.mail", localizedName: "Mail"),
            settings: .init()
        )

        #expect(result.profile == .email)
        #expect(result.category == "email")
    }

    @Test func manualProfileOverrideWinsOverTargetApp() {
        let resolver = AppProfileResolver()
        var settings = PostProcessingSettings()
        settings.outputProfile = .email

        let result = resolver.resolve(
            app: ForegroundAppInfo(bundleIdentifier: "com.microsoft.VSCode", localizedName: "Visual Studio Code"),
            settings: settings
        )

        #expect(result.profile == .email)
        #expect(result.category == "manual")
    }
}
