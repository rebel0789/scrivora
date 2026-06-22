# Scrivora v0.4.1

Private local dictation for macOS. Speak, and your Mac writes.

## Download

Download `Scrivora-0.4.1-preview-unnotarized.dmg`, open it, and drag
`Scrivora.app` into Applications.

No account. No card. Core dictation does not use a cloud speech API.

## Homebrew

Homebrew can install the free preview and remove quarantine from Scrivora only.
Homebrew requires explicit trust for third-party casks:

```bash
brew tap rebel0789/scrivora https://github.com/rebel0789/scrivora
brew trust rebel0789/scrivora
brew install --cask scrivora
```

If Homebrew says the app already exists:

```bash
rm -rf "/Applications/Scrivora.app"
brew install --cask scrivora
```

## What changed

- Fresh onboarding for privacy, model selection, and macOS permissions.
- Parakeet V3 default local transcription path.
- Model downloads now show progress, transfer speed, and time remaining.
- Safer model selection when a saved model is missing or unsupported.
- Menu bar app behavior, latest transcript copy, and update metadata flow.
- Static website and update feed at `https://scrivora.me`.
- MIT-licensed source release.

## macOS warning

This free preview DMG is not Apple notarized. If macOS says Scrivora is damaged
after you drag it into Applications, remove quarantine from Scrivora only:

```bash
sudo xattr -rd com.apple.quarantine "/Applications/Scrivora.app"
open "/Applications/Scrivora.app"
```

Do not disable Gatekeeper globally.

## Checksums

Download `SHA256SUMS.txt` from this release and compare it with:

```bash
shasum -a 256 ~/Downloads/Scrivora-0.4.1-preview-unnotarized.dmg
```
