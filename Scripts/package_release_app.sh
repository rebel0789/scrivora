#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/Scrivora.app"
RELEASE_DIR="$ROOT/.build/release-artifacts"
BUNDLE_ID="${SCRIVORA_BUNDLE_ID:-me.scrivora.app}"
APP_VERSION="${SCRIVORA_VERSION:-0.4.1}"
ZIP="$RELEASE_DIR/Scrivora-${APP_VERSION}.zip"
REUSE_APP="${SCRIVORA_REUSE_RELEASE_APP:-0}"
UPDATE_MANIFEST_URL="${SCRIVORA_UPDATE_MANIFEST_URL:-}"
UPDATE_DEVELOPER_TEAM_ID="${SCRIVORA_UPDATE_DEVELOPER_TEAM_ID:-}"

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "DEVELOPER_ID_APPLICATION is required for release packaging." >&2
  echo "Example: export DEVELOPER_ID_APPLICATION='Developer ID Application: Example, Inc. (TEAMID)'" >&2
  exit 2
fi

if [[ -n "$UPDATE_MANIFEST_URL" && -z "$UPDATE_DEVELOPER_TEAM_ID" ]]; then
  echo "SCRIVORA_UPDATE_DEVELOPER_TEAM_ID is required when SCRIVORA_UPDATE_MANIFEST_URL is set." >&2
  echo "This Team ID is embedded in the app and used to verify updater installs." >&2
  exit 2
fi

if ! command -v codesign >/dev/null 2>&1; then
  echo "codesign is required." >&2
  exit 2
fi

if ! command -v ditto >/dev/null 2>&1; then
  echo "ditto is required." >&2
  exit 2
fi

mkdir -p "$RELEASE_DIR"

if [[ "$REUSE_APP" == "1" ]]; then
  if [[ ! -d "$APP" ]]; then
    echo "SCRIVORA_REUSE_RELEASE_APP=1 was set, but app does not exist: $APP" >&2
    exit 2
  fi
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  SCRIVORA_BUNDLE_ID="$BUNDLE_ID" \
  SCRIVORA_VERSION="$APP_VERSION" \
  SCRIVORA_UPDATE_MANIFEST_URL="$UPDATE_MANIFEST_URL" \
  SCRIVORA_UPDATE_DEVELOPER_TEAM_ID="$UPDATE_DEVELOPER_TEAM_ID" \
  LOCALVOICEFLOW_CODESIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
  "$ROOT/Scripts/package_app_bundle.sh" >/dev/null

  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP"
fi

BUNDLED_UPDATE_MANIFEST_URL="$(/usr/libexec/PlistBuddy -c "Print :ScrivoraUpdateManifestURL" "$APP/Contents/Info.plist" 2>/dev/null || true)"
BUNDLED_UPDATE_DEVELOPER_TEAM_ID="$(/usr/libexec/PlistBuddy -c "Print :ScrivoraUpdateDeveloperTeamID" "$APP/Contents/Info.plist" 2>/dev/null || true)"
if [[ -n "$BUNDLED_UPDATE_MANIFEST_URL" && -z "$BUNDLED_UPDATE_DEVELOPER_TEAM_ID" ]]; then
  echo "Release app has ScrivoraUpdateManifestURL but no ScrivoraUpdateDeveloperTeamID." >&2
  echo "Set SCRIVORA_UPDATE_DEVELOPER_TEAM_ID before packaging updater-enabled releases." >&2
  exit 2
fi

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | sed -n '/Identifier=/p;/Authority=/p;/TeamIdentifier=/p;/Runtime Version=/p'

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "$ZIP"
