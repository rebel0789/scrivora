# Distribution

Scrivora has two separate release tracks:

- User release: publish `Scrivora-0.4.1.dmg`. Users open it, drag
  `Scrivora.app` into Applications, and run the menu bar app.
- Source release: publish the code for people who want to inspect, edit, or
  build Scrivora themselves.

Use `RELEASE_STATUS.md` for the current release state.

## User Install

The public install path should stay this simple:

1. Download `Scrivora-0.4.1.dmg` from the GitHub release.
2. Open the DMG.
3. Drag `Scrivora.app` into `/Applications`.
4. Open Scrivora and grant Microphone and Accessibility when macOS asks.

Users do not need Swift, Xcode, or a local build.

The DMG must be Developer ID signed, notarized, stapled, and accepted by
Gatekeeper before it is attached to a public release. Do not upload or link a
local development-signed DMG; macOS will reject it after download.

## Local Development Install

Build, install, and open a local app bundle:

```bash
swift test
Scripts/install_app_bundle.sh
open /Applications/Scrivora.app
```

Current local development defaults:

- App path: `/Applications/Scrivora.app`
- Executable: `/Applications/Scrivora.app/Contents/MacOS/LocalVoiceFlowApp`
- Bundle ID: `me.scrivora.app`
- Development signing identity: `LocalVoiceFlow Development`

Development signing material belongs under ignored `.build/dev-signing`.

Useful scripts:

```bash
Scripts/create_local_codesign_identity.sh
Scripts/package_dev_app.sh
Scripts/package_app_bundle.sh
Scripts/install_app_bundle.sh
Scripts/clean_dev_signing_material.sh
Scripts/audit_sensitive_files.sh
```

## GitHub Source Release

Private staging remote:

```text
https://github.com/rebel0789/scrivora
```

Before making the repo public:

```bash
swift test
swift build --product LocalVoiceFlowApp
Scripts/audit_sensitive_files.sh
Scripts/stage_site.sh
```

Then verify the tracked file list:

```bash
git ls-files | rg '\\.(zip|dmg|app|p12|cer|key|pem|mobileprovision|keychain|keychain-db|wav|mp3|bin|gguf|mlmodel|mlpackage)$'
```

The command should print nothing for release-sensitive artifacts.

## Public Mac Distribution

Public distribution outside the Mac App Store requires:

- Developer ID Application certificate.
- Hardened runtime.
- Notarization.
- Stapling.
- Gatekeeper verification on a clean Mac.
- Clean Microphone and Accessibility permission flow.

The website can host release notes and update metadata. It does not replace
Apple signing or notarization.

## Website And Update Metadata

The public website target is:

```text
https://scrivora.me
```

The intended stable updater URL is:

```text
https://scrivora.me/updates/stable.json
```

Keep `updates/stable.example.json` and `UPDATE_MANIFEST.example.json` as
templates until the exact ZIP URL, byte size, and SHA-256 are known.

## Release Scripts

The release scripts are fail-closed. They require signing and notarization
inputs instead of silently producing a public-looking unsigned app.

```bash
Scripts/package_release_app.sh
Scripts/package_release_dmg.sh
Scripts/notarize_release_app.sh
Scripts/staple_release_app.sh
Scripts/verify_release_app.sh
Scripts/verify_release_dmg.sh
```

Required environment for a signed app build:

```bash
export SCRIVORA_BUNDLE_ID="me.scrivora.app"
export SCRIVORA_VERSION="0.4.1"
export SCRIVORA_UPDATE_MANIFEST_URL="https://scrivora.me/updates/stable.json"
export SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="<APPLE_TEAM_ID>"
export DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<APPLE_TEAM_ID>)"
```

Notarization should use a stored notarytool keychain profile:

```bash
export NOTARYTOOL_KEYCHAIN_PROFILE="ScrivoraNotaryProfile"
```

Do not pass Apple app-specific passwords on long-running command lines.

## Release Order

1. Run tests and sensitive-file audit.
2. Build the release app.
3. Sign with Developer ID and hardened runtime.
4. Notarize the app archive.
5. Staple the app.
6. Verify the app.
7. Rebuild the updater ZIP from the stapled app.
8. Build the DMG from the stapled app.
9. Notarize the DMG.
10. Staple the DMG.
11. Verify the DMG on a clean Mac.
12. Upload DMG and updater ZIP to the versioned GitHub Release:
    `https://github.com/rebel0789/scrivora/releases/tag/v0.4.1`.
13. Generate `updates/stable.json` from the uploaded updater ZIP.
14. Publish the website and update manifest.
15. Smoke test the website download and in-app update from a fresh machine or
    clean user profile.

## Permission Stability

macOS privacy permissions are tied to app identity and signing requirement.
Changing the app path, bundle ID, or signing identity can trigger fresh
Microphone or Accessibility prompts.

For local testing, keep these stable unless you are intentionally testing a
fresh permission flow:

- `/Applications/Scrivora.app`
- `me.scrivora.app`
- `LocalVoiceFlow Development`
