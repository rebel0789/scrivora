# Scrivora Release Status

Last updated: 2026-06-20

This file is the release source of truth for the repo. Older audit and planning
files are historical unless they point here.

## Current Position

Scrivora is staged for private GitHub review at
`https://github.com/rebel0789/scrivora`.

The source tree can move from private review to public release after the source
license is chosen and the final clean-clone check passes.

The public Mac binary download track is gated on Developer ID signing,
notarization, stapling, and Gatekeeper acceptance on a clean Mac.

## Tracks

| Track | Status | Next gate |
| --- | --- | --- |
| Source repo | Private staging | Choose license and add `LICENSE` before public visibility. |
| Website | Prepared locally | Publish after GitHub links and domain target are confirmed. |
| GitHub Pages | Workflow prepared | Enable after the repo visibility and domain target are confirmed. |
| Vercel | Static bundle prepared | Re-authenticate Vercel and attach `scrivora.me` only after confirmation. |
| Mac app DMG | Scripted | Developer ID signing, notarization, stapling, Gatekeeper check. |
| In-app update manifest | Template only | Generate `updates/stable.json` from the final signed ZIP and uploaded URL. |

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
- Live updater manifest before signed release artifacts exist.

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
- `updates/stable.json` is intentionally absent until the final signed updater
  ZIP and SHA-256 exist.

Release rule: do not bundle model weights or publish a live updater manifest
until the exact artifact, hash, and license obligations are known.

## Required Before Making The GitHub Repo Public

1. Pick the source license and add `LICENSE`.
2. Confirm the copyright owner text.
3. Review `MODEL_LICENSES.md` and `THIRD_PARTY_NOTICES.md`.
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
6. Review `README.md`, `SECURITY.md`, `CONTRIBUTING.md`, and this file.
7. Push to `https://github.com/rebel0789/scrivora`, not a scratch checkout with
   no remote.

## Required Before Publishing A Mac Download

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
10. Publish the website and update manifest only after the artifact URL works.

## Do Not Claim Until Verified

- App Store availability.
- Notarized public download.
- Live hosted updates.
- Model-weight redistribution.
- Cloud-free behavior for future optional cloud features.
- Security bounty or SLA.
