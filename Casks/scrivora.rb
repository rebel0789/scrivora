cask "scrivora" do
  version "0.4.1"
  sha256 "1d6115e46208786c0daaf2c0f4a8f3e6fb9ec618271dd177512bb52ae094e10f"

  url "https://github.com/rebel0789/scrivora/releases/download/v#{version}/Scrivora-#{version}-preview-unnotarized.dmg",
      verified: "github.com/rebel0789/scrivora/"
  name "Scrivora"
  desc "Private local voice writing for macOS"
  homepage "https://scrivora.me"

  app "Scrivora.app"

  preflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{staged_path}/Scrivora.app"],
                   must_succeed: false
  end

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/Scrivora.app"],
                   must_succeed: false
  end

  zap trash: [
    "~/Library/Application Support/LocalVoiceFlow",
    "~/Library/Application Support/Scrivora",
    "~/Library/Caches/me.scrivora.app",
    "~/Library/Preferences/me.scrivora.app.plist",
    "~/Library/Saved Application State/me.scrivora.app.savedState",
  ]

  caveats <<~EOS
    Scrivora's free preview DMG is not Apple notarized.
    This cask tries to remove quarantine from Scrivora.app only.

    If macOS still says it cannot verify Scrivora, remove quarantine from the
    downloaded DMG before opening it, then drag Scrivora into Applications again:
      xattr -d com.apple.quarantine ~/Downloads/Scrivora-0.4.1-preview-unnotarized.dmg
  EOS
end
