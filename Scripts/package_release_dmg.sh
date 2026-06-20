#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/Scrivora.app"
RELEASE_DIR="$ROOT/.build/release-artifacts"
APP_VERSION="${SCRIVORA_VERSION:-0.4.1}"
DMG="$RELEASE_DIR/Scrivora-${APP_VERSION}.dmg"
STAGING_ROOT="$ROOT/.build/dmg-staging"
STAGING="$STAGING_ROOT/Scrivora"
REUSE_APP="${SCRIVORA_REUSE_RELEASE_APP:-0}"

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "DEVELOPER_ID_APPLICATION is required for release DMG packaging." >&2
  echo "Example: export DEVELOPER_ID_APPLICATION='Developer ID Application: Example, Inc. (TEAMID)'" >&2
  exit 2
fi

for tool in hdiutil ditto codesign; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required." >&2
    exit 2
  fi
done

if [[ "$REUSE_APP" == "1" ]]; then
  if [[ ! -d "$APP" ]]; then
    echo "SCRIVORA_REUSE_RELEASE_APP=1 was set, but app does not exist: $APP" >&2
    exit 2
  fi
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  "$ROOT/Scripts/package_release_app.sh" >/dev/null
fi

BUNDLED_UPDATE_MANIFEST_URL="$(/usr/libexec/PlistBuddy -c "Print :ScrivoraUpdateManifestURL" "$APP/Contents/Info.plist" 2>/dev/null || true)"
BUNDLED_UPDATE_DEVELOPER_TEAM_ID="$(/usr/libexec/PlistBuddy -c "Print :ScrivoraUpdateDeveloperTeamID" "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -n "$BUNDLED_UPDATE_MANIFEST_URL" && -z "$BUNDLED_UPDATE_DEVELOPER_TEAM_ID" ]]; then
  echo "Release app has ScrivoraUpdateManifestURL but no ScrivoraUpdateDeveloperTeamID." >&2
  echo "Set SCRIVORA_UPDATE_DEVELOPER_TEAM_ID before packaging updater-enabled releases." >&2
  exit 2
fi

rm -rf "$STAGING_ROOT"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Scrivora.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
  -volname "Scrivora" \
  -srcfolder "$STAGING" \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

codesign --force --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$DMG"
codesign --verify --verbose=2 "$DMG"
hdiutil verify "$DMG" >/dev/null

echo "$DMG"
