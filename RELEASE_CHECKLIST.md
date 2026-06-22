# Scrivora Release Checklist

Use this before publishing the source repo, website, GitHub Release, DMG, or
update manifest.

## Source Repo

- [ ] Confirm `LICENSE` is present and copyright owner text is current.
- [ ] Review `MODEL_LICENSES.md` and `THIRD_PARTY_NOTICES.md`.
- [ ] Run:

  ```bash
  swift test
  swift build --product LocalVoiceFlowApp
  Scripts/audit_sensitive_files.sh
  Scripts/stage_site.sh
  ```

- [ ] Confirm no model weights, transcripts, recordings, logs, app bundles,
      zips, DMGs, keychains, certificates, profiles, signing passwords, or local
      app-support data are tracked.
- [ ] Confirm `README.md`, `RELEASE_STATUS.md`, `SECURITY.md`,
      `CONTRIBUTING.md`, and `.github/` templates match the public scope.
- [ ] Confirm `Package.swift` and `Package.resolved` use public dependencies.
- [ ] Build from a clean clone or clean worktree before the public tag.

## GitHub

- [ ] Confirm the intended GitHub remote:

  ```bash
  git remote -v
  ```

- [ ] Confirm `origin` is `https://github.com/rebel0789/scrivora.git`.
- [ ] Push the source release branch.
- [ ] Confirm GitHub Actions runs `swift test`, app build, sensitive-file audit,
      and site staging.
- [ ] Enable GitHub Pages only after the domain target is confirmed.
- [ ] Create the `v0.4.1` tag only after the source checklist passes.

## Website

- [ ] Confirm `CNAME` is `scrivora.me`.
- [ ] Confirm `index.html`, `releases/v0.4.1.html`, `robots.txt`,
      `sitemap.xml`, `site.webmanifest`, and `tokens.css` have current copy.
- [ ] Run `Scripts/stage_site.sh`.
- [ ] Open the staged site locally and check mobile widths: `320`, `375`,
      `414`, and `768`.
- [ ] Deploy the staged `.site` bundle through GitHub Pages or Vercel.
- [ ] Open `https://scrivora.me` after DNS settles.

## Mac App Download

- [ ] For the free OSS preview path, build the preview DMG:

  ```bash
  SCRIVORA_PREVIEW_APP=/Applications/Scrivora.app Scripts/package_preview_dmg.sh
  Scripts/generate_release_checksums.sh \
    .build/release-artifacts \
    .build/release-artifacts/SHA256SUMS.txt \
    .build/release-artifacts/Scrivora-0.4.1-preview-unnotarized.dmg
  ```

- [ ] Upload `Scrivora-0.4.1-preview-unnotarized.dmg` and `SHA256SUMS.txt` to
      the GitHub release.
- [ ] Confirm the README, release page, and GitHub release body include:
      manual download, Homebrew `--no-quarantine`, SHA-256 check, and the
      per-app quarantine removal command. Do not include global Gatekeeper
      disable instructions.
- [ ] Confirm the DMG mounts, contains `Scrivora.app` plus the Applications
      shortcut, and copied app verification passes.

## Paid Developer ID Release

- [ ] Set release inputs:

  ```bash
  export SCRIVORA_BUNDLE_ID="me.scrivora.app"
  export SCRIVORA_VERSION="0.4.1"
  export SCRIVORA_UPDATE_MANIFEST_URL="https://scrivora.me/updates/stable.json"
  export SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="<APPLE_TEAM_ID>"
  export DEVELOPER_ID_APPLICATION="Developer ID Application: <NAME> (<APPLE_TEAM_ID>)"
  export NOTARYTOOL_KEYCHAIN_PROFILE="ScrivoraNotaryProfile"
  ```

- [ ] Build the release app ZIP:

  ```bash
  Scripts/package_release_app.sh
  ```

- [ ] Notarize the ZIP.
- [ ] Staple and verify `.build/Scrivora.app`.
- [ ] Rebuild the updater ZIP from the stapled app:

  ```bash
  export SCRIVORA_REUSE_RELEASE_APP=1
  Scripts/package_release_app.sh
  unset SCRIVORA_REUSE_RELEASE_APP
  ```

- [ ] Build the website DMG from the stapled app:

  ```bash
  export SCRIVORA_REUSE_RELEASE_APP=1
  Scripts/package_release_dmg.sh
  unset SCRIVORA_REUSE_RELEASE_APP
  ```

- [ ] Notarize, staple, and verify the DMG.
- [ ] Test the DMG on a clean Mac or clean user profile.
- [ ] Verify Microphone and Accessibility prompts from a fresh install.
- [ ] Dictate into Notes, Chrome, TextEdit, and one Electron app.

## In-App Updates

- [ ] Upload the final updater ZIP to a versioned GitHub Release asset URL.
- [ ] Generate the manifest from that exact ZIP:

  ```bash
  export SCRIVORA_VERSION="0.4.1"
  export SCRIVORA_RELEASE_NOTES_URL="https://scrivora.me/releases/v0.4.1.html"
  export SCRIVORA_RELEASE_NOTES="Realtime local dictation with private defaults.|Menu bar model switching and latest transcript copy.|Parakeet V3 default with explicit model downloads."

  Scripts/create_update_manifest.sh \
    .build/release-artifacts/Scrivora-0.4.1.zip \
    "https://github.com/rebel0789/scrivora/releases/download/v0.4.1/Scrivora-0.4.1.zip" \
    updates/stable.json
  ```

- [ ] Confirm `updates/stable.json` has the exact URL, byte size, and SHA-256.
- [ ] Publish `updates/stable.json` only after the ZIP URL is live.
- [ ] Check updates from the installed app.
- [ ] Install through the updater on a clean Mac or clean user profile.

## Final Preview Checks

- [ ] `https://scrivora.me/` links the preview DMG.
- [ ] `https://scrivora.me/releases/v0.4.1.html` links the preview DMG and
      `SHA256SUMS.txt`.
- [ ] The GitHub release includes the preview DMG, `SHA256SUMS.txt`, source
      tag, and release notes.
- [ ] The damaged-app instructions remove quarantine from
      `/Applications/Scrivora.app` only.

## Final Developer ID Checks

- [ ] `spctl --assess --type execute --verbose=4 /Applications/Scrivora.app`
      accepts the installed app.
- [ ] `Scripts/verify_release_dmg.sh .build/release-artifacts/Scrivora-0.4.1.dmg`
      passes.
- [ ] `https://scrivora.me/updates/stable.json` points at the exact uploaded
      updater ZIP.
- [ ] The GitHub release includes source tag, DMG, updater ZIP, SHA-256, and
      release notes.
