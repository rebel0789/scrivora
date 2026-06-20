#!/usr/bin/env bash
set -euo pipefail

DMG="${1:-}"

if [[ -z "$DMG" || ! -f "$DMG" ]]; then
  echo "Usage: Scripts/verify_release_dmg.sh path/to/Scrivora.dmg" >&2
  exit 2
fi

hdiutil verify "$DMG" >/dev/null
codesign --verify --verbose=2 "$DMG"
DMG_SIGNATURE="$(codesign -dvvv "$DMG" 2>&1)"
printf '%s\n' "$DMG_SIGNATURE" | sed -n '/Authority=/p;/TeamIdentifier=/p'
if ! printf '%s\n' "$DMG_SIGNATURE" | grep -q '^Authority=Developer ID Application:'; then
  echo "Release DMG is not signed with a Developer ID Application identity." >&2
  echo "Do not publish this artifact; browser-downloaded copies can be rejected as damaged by Gatekeeper." >&2
  exit 1
fi
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"

MOUNT_OUTPUT="$(hdiutil attach "$DMG" -readonly -nobrowse)"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Could not determine mounted DMG volume." >&2
  exit 1
fi

cleanup() {
  hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

APP="$MOUNT_POINT/Scrivora.app"
if [[ ! -d "$APP" ]]; then
  echo "Scrivora.app not found inside DMG." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | sed -n '/Identifier=/p;/Authority=/p;/TeamIdentifier=/p;/Runtime Version=/p'
spctl --assess --type execute --verbose=4 "$APP"
