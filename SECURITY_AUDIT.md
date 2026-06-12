# Scrivora Security Audit

Date: 2026-06-12

## Scope

This audit covers the local SwiftPM macOS app, local storage, packaging scripts, privacy export, and development signing material.

## Findings

### Fixed: Dev Signing Material In App Support

Previous state:

```text
~/Library/Application Support/LocalVoiceFlow/Signing
```

contained a local development keychain, certificate, key, p12, and password file.

Current state:

```text
.build/dev-signing
```

contains the dev-only signing identity and is ignored by git.

The old app support signing folder was moved out. Current check found no signing files under normal LocalVoiceFlow app support.

### Fixed: Missing Secret Ignore Rules

`.gitignore` now includes:

- `*.p12`
- `*.cer`
- `*.key`
- `*.pem`
- `*.mobileprovision`
- `*.keychain`
- `*.keychain-db`
- `signing-password*`
- `Signing/`
- `.build/dev-signing/`

### Fixed: No Export Redaction Contract

Redacted debug export now removes transcript text, correction text, target metadata, bundle identifiers, learned phrase entries, and local paths.

### Fixed: Offline Mode Did Not Have A Testable Policy

Offline Mode now has a core policy:

- Remote model downloads blocked.
- Local models allowed.
- Localhost services allowed.

### Accepted Risk: Development Signing Is Not Production Signing

`LocalVoiceFlow Development` is a local self-signed identity. It is useful for stable macOS permissions during MVP testing, but it is not a distribution identity.

### Accepted Risk: User-Configured Binaries

The user can configure whisper binary/server paths. Scrivora does not sandbox those binaries. The UI and docs must treat those paths as trusted local executables.

### Accepted Risk: Clipboard Restoration Timing

Clipboard restoration is delay-based. Some target apps may paste slowly. The transcript is copied first, so failed Accessibility paste still leaves manual paste available.

## Latest Audit Command

```bash
Scripts/audit_sensitive_files.sh
```

Latest result:

- Signing material candidates: only ignored `.build/dev-signing` files.
- Scrivora audio/temp candidates outside model caches: none.
- Local text data stores: settings, learning, logs, and history exist on this Mac.

Those text stores are local user data and can be cleared in Settings -> Privacy.

## Verification

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/package_app_bundle.sh
codesign -dv --verbose=4 /Applications/Scrivora.app
plutil -p /Applications/Scrivora.app/Contents/Info.plist
```

Latest results:

- 49 tests passed.
- App product build passed.
- Package script passed.
- Installed bundle version: `0.3.0`.
- Installed bundle ID: `app.localvoiceflow.mvp`.
- Installed signing authority: `LocalVoiceFlow Development`.

## Required Before Public Release

- Developer ID Application signing.
- Hardened runtime entitlement review.
- Notarization and stapling.
- Release artifact hash.
- Clean install test on another Mac.
- Permission reset/regrant test on another Mac.
