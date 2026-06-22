# Scrivora Update Manifests

The production updater URL is:

```text
https://scrivora.me/updates/stable.json
```

Publish `stable.json` with the versioned GitHub Release assets. In the free
release path, Scrivora uses it for update metadata and opens the release page so
users can download the DMG. In a Developer ID build, the same feed can drive
in-app replacement updates.

The manifest must contain the SHA-256 and byte size of the exact uploaded ZIP.
Use:

```bash
export SCRIVORA_VERSION="0.4.1"
export SCRIVORA_RELEASE_NOTES_URL="https://scrivora.me/releases/v0.4.1.html"
export SCRIVORA_RELEASE_NOTES="Menu bar model switching and last transcript copy.|Parakeet V3 default with improved model management.|Verified in-app update flow and release metadata."

Scripts/create_update_manifest.sh \
  .build/release-artifacts/Scrivora-0.4.1.zip \
  "https://github.com/$GITHUB_REPOSITORY/releases/download/v0.4.1/Scrivora-0.4.1.zip" \
  updates/stable.json
```

Commit or deploy `updates/stable.json` only after the uploaded GitHub Release
asset URL matches the URL in the manifest.
