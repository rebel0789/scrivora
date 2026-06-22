cask "scrivora" do
  version "0.4.1"
  sha256 "c394c17f487fdd1153c22804ad3bb0b870bbdea2a83f3cc2477b1239f66a70da"

  url "https://github.com/rebel0789/scrivora/releases/download/v#{version}/Scrivora-#{version}-preview-unnotarized.dmg",
      verified: "github.com/rebel0789/scrivora/"
  name "Scrivora"
  desc "Private local voice writing for macOS"
  homepage "https://scrivora.me"

  app "Scrivora.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-rd", "com.apple.quarantine", "#{appdir}/Scrivora.app"],
                   sudo: true
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
    The cask postflight removes quarantine from Scrivora.app only.

    If macOS still says the app is damaged, run:
      sudo xattr -rd com.apple.quarantine "/Applications/Scrivora.app"
  EOS
end
