#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${SCRIVORA_PREVIEW_APP:-$ROOT/.build/Scrivora.app}"
VERSION="${SCRIVORA_VERSION:-0.4.1}"
RELEASE_DIR="$ROOT/.build/release-artifacts"
STAGING_ROOT="$RELEASE_DIR/preview-dmg"
STAGING="$STAGING_ROOT/Scrivora"
DMG="$RELEASE_DIR/Scrivora-${VERSION}-preview-unnotarized.dmg"
RW_DMG="$RELEASE_DIR/Scrivora-${VERSION}-preview-layout.dmg"

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

rm -rf "$STAGING_ROOT" "$DMG" "$RW_DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Scrivora.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Scrivora" \
  -srcfolder "$STAGING" \
  -format UDRW \
  -ov \
  "$RW_DMG" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\/Scrivora/ { for (i = 1; i <= NF; i++) if ($i ~ /^\/Volumes\//) { print $i; exit } }')"

if [[ -n "${MOUNT_POINT:-}" && "${SCRIVORA_DMG_SKIP_FINDER_LAYOUT:-0}" != "1" ]]; then
  (
  osascript <<'APPLESCRIPT'
tell application "Finder"
  tell disk "Scrivora"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {140, 120, 780, 470}

    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background color of viewOptions to {62700, 59000, 55400}

    set position of item "Scrivora.app" of container window to {185, 185}
    set position of item "Applications" of container window to {455, 185}
    update without registering applications
    delay 0.5
    close
  end tell
end tell
APPLESCRIPT
  ) &
  LAYOUT_PID=$!
  LAYOUT_TIMEOUT_SECONDS="${SCRIVORA_DMG_FINDER_LAYOUT_TIMEOUT:-8}"
  LAYOUT_DEADLINE=$((SECONDS + LAYOUT_TIMEOUT_SECONDS))
  while kill -0 "$LAYOUT_PID" >/dev/null 2>&1 && [[ "$SECONDS" -lt "$LAYOUT_DEADLINE" ]]; do
    sleep 0.2
  done
  if kill -0 "$LAYOUT_PID" >/dev/null 2>&1; then
    kill "$LAYOUT_PID" >/dev/null 2>&1 || true
  fi
  wait "$LAYOUT_PID" >/dev/null 2>&1 || true
  sync
fi

if [[ -n "${MOUNT_POINT:-}" ]]; then
  hdiutil detach "$MOUNT_POINT" >/dev/null
fi

hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG" >/dev/null

rm -f "$RW_DMG"

hdiutil verify "$DMG" >/dev/null
echo "$DMG"
