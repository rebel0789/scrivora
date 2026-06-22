# Scrivora Release Status

Last updated: 2026-06-22

This file is the release source of truth for the repo. Older audit and planning
files are historical unless they point here.

## Current Position

Scrivora source is prepared for public GitHub release at
`https://github.com/rebel0789/scrivora`.

The public product path is a prebuilt Mac DMG: download, open, drag Scrivora into
Applications, then start dictating from the menu bar.

The source tree is for people who want to inspect, edit, or build Scrivora
themselves.

## Tracks

| Track | Status | Next gate |
| --- | --- | --- |
| Source repo | Ready for public visibility | MIT license added; keep release-sensitive artifacts out of git. |
| Website | Live | `https://scrivora.me` is served by GitHub Pages. |
| GitHub Pages | Live | HTTPS is enforced for `scrivora.me`. |
| Vercel | Static bundle prepared | Re-authenticate Vercel and attach `scrivora.me` only after confirmation. |
| Mac app DMG | Free preview live | GitHub Release hosts the DMG and checksums. Manual install and Homebrew cask install are supported; notarized Developer ID build remains a later track. |
| In-app update manifest | Ready for metadata feed | `updates/stable.json` points at the GitHub Release ZIP and release notes. Free builds open the release page for download. |

## Current Product Scope

Included in the first public source release:

- Native macOS menu bar app.
- Hold Control, double-tap Control, and configurable global shortcut triggers.
- Local microphone capture, chunking, VAD, and cleanup pipeline.
- Local FluidAudio Parakeet V2/V3 path.
- Local whisper.cpp fallback model downloads.
- Model library UI with explicit download/delete behavior.
- Clipboard insertion and safe copy fallback.
- Privacy settings, local history controls, redacted export, and sensitive-file audit.
- Static website, release notes, update-manifest templates, and GitHub workflows.

Not included:

- Hosted account system.
- Payment or card capture.
- Hosted transcript storage.
- Bundled speech model weights.

## Security Status

The prior security audits found the right release risks: updater trust policy,
model download integrity, redacted export leakage, notarization credential
handling, and release-script identity checks.

Current status from repo inspection:

- Updater installs are fail-closed in app code. The app verifies manifest
  bundle ID and version, archive SHA-256, `codesign --verify --deep --strict`,
  non-ad-hoc signing, configured Developer ID Team ID, and Gatekeeper before
  replacing `/Applications/Scrivora.app`.
- Fresh whisper.cpp downloads require pinned SHA-256 values.
- FluidAudio downloads and app selection use pinned cache checks before a model
  is treated as downloaded.
- Redacted privacy export scrubs transcript text, target app metadata, bundle
  identifiers, local paths, and diagnostic failure strings.
- Release scripts use `notarytool` keychain profiles and keep Apple credentials
  off long-running command lines.
- `updates/stable.json` is generated from the current updater ZIP. Free builds
  use it for release metadata and open the release page for download.

Release rule: do not bundle model weights. Keep the update manifest hash tied
to the exact ZIP uploaded to the GitHub Release.

## Public Source Release Checklist

1. Confirm the MIT license and copyright owner text.
2. Review `MODEL_LICENSES.md` and `THIRD_PARTY_NOTICES.md`.
3. Confirm `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, and this file.
4. Run:

   ```bash
   swift test
   swift build --product LocalVoiceFlowApp
   Scripts/audit_sensitive_files.sh
   Scripts/stage_site.sh
   ```

5. Confirm no generated binaries, model weights, transcripts, recordings, logs,
   app bundles, zips, DMGs, keychains, certificates, or signing profiles are
   tracked.
6. Push to `https://github.com/rebel0789/scrivora`, not a scratch checkout with
   no remote.

## Current Free Mac Install Path

The public download is a free OSS preview. Normal users download the DMG, drag
Scrivora into Applications, and grant macOS permissions during onboarding.

If macOS blocks the unnotarized app, users should remove quarantine from
Scrivora only:

```bash
sudo xattr -rd com.apple.quarantine "/Applications/Scrivora.app"
open "/Applications/Scrivora.app"
```

Homebrew users can use the cask path:

```bash
brew tap rebel0789/scrivora https://github.com/rebel0789/scrivora
brew trust rebel0789/scrivora
brew install --cask scrivora
```

Do not ask users to disable Gatekeeper globally.

## Required Before Attaching A Notarized DMG

1. Create or install a Developer ID Application certificate.
2. Set:

   ```bash
   export SCRIVORA_BUNDLE_ID="me.scrivora.app"
   export SCRIVORA_VERSION="0.4.1"
   export SCRIVORA_UPDATE_MANIFEST_URL="https://scrivora.me/updates/stable.json"
   export SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="<APPLE_TEAM_ID>"
   export DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<APPLE_TEAM_ID>)"
   ```

3. Build the app ZIP with `Scripts/package_release_app.sh`.
4. Notarize, staple, and verify `.build/Scrivora.app`.
5. Rebuild the updater ZIP from the stapled app.
6. Build, notarize, staple, and verify the DMG.
7. Test install and first dictation on a clean Mac or clean user profile.
8. Upload the ZIP and DMG to a versioned GitHub Release.
9. Generate `updates/stable.json` from the exact uploaded ZIP URL.
10. Publish `updates/stable.json` only after the updater ZIP URL works.

## Do Not Claim Until Verified

- App Store availability.
- Notarized public download.
- Model-weight redistribution.
- Cloud-free behavior for future optional cloud features.
- Security bounty or SLA.
