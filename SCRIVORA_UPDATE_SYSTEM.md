# Scrivora Update System

Date: 2026-06-18

## What Exists Now

Scrivora has an in-app update announcement and direct-update flow.

The app can:

- Read a static JSON update manifest.
- Compare the manifest version against the installed app version.
- Show a focused update dialog with release notes and install actions.
- Show update controls in About -> Updates.
- Download the update zip when the user clicks Install Update.
- Verify the zip SHA-256 before extraction.
- Verify the extracted `.app` bundle ID and version.
- Run `codesign --verify --deep --strict`.
- Reject ad-hoc signatures.
- Require the configured Scrivora Developer ID Team ID.
- Always run Gatekeeper assessment before installation.
- Replace `/Applications/Scrivora.app` and reopen Scrivora through a detached helper process.

The app does not silently update. The user must click Install Update.

## Manifest Format

See:

```text
UPDATE_MANIFEST.example.json
updates/stable.example.json
```

Required fields:

- `appID`
- `version`
- `downloadURL`
- `sha256`

Recommended fields:

- `channel`
- `minimumSystemVersion`
- `archiveSizeBytes`
- `releaseNotesURL`
- `notes`
- `critical`

Production manifests must use HTTPS URLs. The app does not accept a manifest-controlled
Gatekeeper bypass. Local development builds should be installed with
`Scripts/install_app_bundle.sh`, not the in-app updater.

GitHub Releases can host the update zip and website DMG. Use a versioned release
asset URL in `downloadURL`, publish the matching SHA-256 in the manifest, and
point `releaseNotesURL` at `https://scrivora.me/releases/v0.4.1.html` or the
matching release page. Do not use mutable "latest" URLs for updater assets.

## Build A Release Zip

Requires a Developer ID Application identity:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<APPLE_TEAM_ID>)"
export SCRIVORA_BUNDLE_ID="me.scrivora.app"
export SCRIVORA_VERSION="0.4.1"
export SCRIVORA_UPDATE_MANIFEST_URL="https://scrivora.me/updates/stable.json"
export SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="<APPLE_TEAM_ID>"

Scripts/package_release_app.sh
```

This produces:

```text
.build/release-artifacts/Scrivora-0.4.1.zip
```

This first zip is the notarization upload artifact. After notarization, staple the ticket to the app and rebuild the final updater zip from that stapled app:

```bash
export NOTARYTOOL_KEYCHAIN_PROFILE="ScrivoraNotaryProfile"
Scripts/notarize_release_app.sh .build/release-artifacts/Scrivora-0.4.1.zip
Scripts/staple_release_app.sh .build/Scrivora.app
Scripts/verify_release_app.sh .build/Scrivora.app

export SCRIVORA_REUSE_RELEASE_APP=1
Scripts/package_release_app.sh
unset SCRIVORA_REUSE_RELEASE_APP
```

For the public website download, build a signed drag-to-Applications DMG from the stapled app:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<APPLE_TEAM_ID>)"
export SCRIVORA_BUNDLE_ID="me.scrivora.app"
export SCRIVORA_VERSION="0.4.1"
export SCRIVORA_UPDATE_MANIFEST_URL="https://scrivora.me/updates/stable.json"
export SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="<APPLE_TEAM_ID>"
export SCRIVORA_REUSE_RELEASE_APP=1

Scripts/package_release_dmg.sh
unset SCRIVORA_REUSE_RELEASE_APP
```

This produces:

```text
.build/release-artifacts/Scrivora-0.4.1.dmg
```

## Notarize And Verify

Create a notarytool keychain profile once:

```bash
xcrun notarytool store-credentials "ScrivoraNotaryProfile" \
  --apple-id "<APPLE_ID_EMAIL>" \
  --team-id "<APPLE_TEAM_ID>"
```

Then notarize with the saved profile if you have not already done the app zip step above:

```bash
export NOTARYTOOL_KEYCHAIN_PROFILE="ScrivoraNotaryProfile"
Scripts/notarize_release_app.sh .build/release-artifacts/Scrivora-0.4.1.zip
Scripts/staple_release_app.sh .build/Scrivora.app
Scripts/verify_release_app.sh .build/Scrivora.app
```

For the website DMG:

```bash
export NOTARYTOOL_KEYCHAIN_PROFILE="ScrivoraNotaryProfile"
Scripts/notarize_release_app.sh .build/release-artifacts/Scrivora-0.4.1.dmg
Scripts/staple_release_app.sh .build/release-artifacts/Scrivora-0.4.1.dmg
Scripts/verify_release_dmg.sh .build/release-artifacts/Scrivora-0.4.1.dmg
```

Do not commit or print Apple credentials.

## Create The Manifest

```bash
export SCRIVORA_BUNDLE_ID="me.scrivora.app"
export SCRIVORA_VERSION="0.4.1"
export SCRIVORA_UPDATE_CHANNEL="stable"
export SCRIVORA_RELEASE_NOTES_URL="https://scrivora.me/releases/v0.4.1.html"
export SCRIVORA_RELEASE_NOTES="Menu bar model switching and last transcript copy.|Parakeet V3 default with improved model management.|Verified in-app update flow and release metadata."

Scripts/create_update_manifest.sh \
  .build/release-artifacts/Scrivora-0.4.1.zip \
  "https://github.com/rebel0789/scrivora/releases/download/v0.4.1/Scrivora-0.4.1.zip" \
  .build/release-artifacts/stable.json
```

Upload both files:

```text
https://github.com/rebel0789/scrivora/releases/download/v0.4.1/Scrivora-0.4.1.zip
https://scrivora.me/updates/stable.json
```

The manifest must point at the exact uploaded zip URL and SHA-256. The public
website can link the DMG from the same GitHub release while the in-app updater
continues to use the zipped `.app` artifact.

The repo keeps `updates/stable.example.json` as a template. Publish
`updates/stable.json` only after it has been generated from the exact ZIP that
will be uploaded to the GitHub Release.

## Configure The App

For release builds, set the manifest at package time:

```bash
SCRIVORA_UPDATE_MANIFEST_URL="https://scrivora.me/updates/stable.json" \
SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="<APPLE_TEAM_ID>" \
Scripts/package_release_app.sh
```

For local testing, open Scrivora:

```text
About -> Updates -> Manifest
```

Paste the manifest URL, then click Check Now. Normal builds now default to
`https://scrivora.me/updates/stable.json`, so this field is mainly useful for
local feed testing.

## Current Limits

- Self-installing in-app updates require Developer ID signing and notarization.
- Free releases can still use the update feed for release metadata and open the
  DMG release page.
- The app does not host update files itself.
- `scrivora.me` is the HTTPS manifest host.
- The update helper assumes Scrivora is installed at `/Applications/Scrivora.app`.
- If macOS permissions on `/Applications` block replacement, the update will fail and the user must install manually.
- Sparkle is not integrated yet. This custom updater is intentionally small and local-first, but Sparkle remains the stronger long-term option for production-grade delta updates and signature policy.
