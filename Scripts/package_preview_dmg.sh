#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${SCRIVORA_PREVIEW_APP:-$ROOT/.build/Scrivora.app}"
VERSION="${SCRIVORA_VERSION:-0.4.1}"
RELEASE_DIR="$ROOT/.build/release-artifacts"
STAGING_ROOT="$RELEASE_DIR/preview-dmg"
STAGING="$STAGING_ROOT/Scrivora"
DMG="$RELEASE_DIR/Scrivora-${VERSION}-preview-unnotarized.dmg"

if [[ ! -d "$APP" ]]; then
  echo "Preview app bundle not found: $APP" >&2
  echo "Run Scripts/package_app_bundle.sh first, or set SCRIVORA_PREVIEW_APP=/Applications/Scrivora.app." >&2
  exit 2
fi

for tool in hdiutil ditto; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required." >&2
    exit 2
  fi
done

rm -rf "$STAGING_ROOT" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Scrivora.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Scrivora" \
  -srcfolder "$STAGING" \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

hdiutil verify "$DMG" >/dev/null
echo "$DMG"
