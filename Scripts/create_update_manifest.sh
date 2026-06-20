#!/usr/bin/env bash
set -euo pipefail

ZIP_PATH="${1:-}"
DOWNLOAD_URL="${2:-}"
OUTPUT_PATH="${3:-}"

if [[ -z "$ZIP_PATH" || -z "$DOWNLOAD_URL" ]]; then
  echo "Usage: Scripts/create_update_manifest.sh path/to/Scrivora-<version>.zip https://example.com/Scrivora-<version>.zip [output.json]" >&2
  exit 2
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Zip not found: $ZIP_PATH" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to write JSON safely." >&2
  exit 2
fi

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
SIZE_BYTES="$(stat -f%z "$ZIP_PATH")"
FILENAME="$(basename "$ZIP_PATH")"
VERSION="${SCRIVORA_VERSION:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(printf '%s' "$FILENAME" | sed -nE 's/^Scrivora-([0-9]+([.][0-9]+)*).*\\.zip$/\\1/p')"
fi
if [[ -z "$VERSION" ]]; then
  echo "Could not infer version from filename. Set SCRIVORA_VERSION." >&2
  exit 2
fi

APP_ID="${SCRIVORA_BUNDLE_ID:-me.scrivora.app}"
CHANNEL="${SCRIVORA_UPDATE_CHANNEL:-stable}"
MINIMUM_SYSTEM_VERSION="${SCRIVORA_MINIMUM_SYSTEM_VERSION:-14.0}"
RELEASE_NOTES_URL="${SCRIVORA_RELEASE_NOTES_URL:-}"
RELEASE_NOTES="${SCRIVORA_RELEASE_NOTES:-Local dictation reliability and updater improvements.}"
CRITICAL="${SCRIVORA_UPDATE_CRITICAL:-false}"

python3 - "$APP_ID" "$VERSION" "$CHANNEL" "$MINIMUM_SYSTEM_VERSION" "$DOWNLOAD_URL" "$SHA256" "$SIZE_BYTES" "$RELEASE_NOTES_URL" "$RELEASE_NOTES" "$CRITICAL" "$OUTPUT_PATH" <<'PY'
import json
import sys

(
    app_id,
    version,
    channel,
    minimum_system_version,
    download_url,
    sha256,
    size_bytes,
    release_notes_url,
    release_notes,
    critical,
    output_path,
) = sys.argv[1:]

notes = [note.strip() for note in release_notes.split("|") if note.strip()]
manifest = {
    "appID": app_id,
    "version": version,
    "build": "1",
    "channel": channel,
    "minimumSystemVersion": minimum_system_version,
    "downloadURL": download_url,
    "sha256": sha256,
    "archiveSizeBytes": int(size_bytes),
    "notes": notes,
    "critical": critical.lower() == "true",
}
if release_notes_url:
    manifest["releaseNotesURL"] = release_notes_url

text = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
if output_path:
    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write(text)
else:
    print(text, end="")
PY
