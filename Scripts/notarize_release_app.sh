#!/usr/bin/env bash
set -euo pipefail

APP_ZIP="${1:-}"

if [[ -z "$APP_ZIP" || ! -f "$APP_ZIP" ]]; then
  echo "Usage: Scripts/notarize_release_app.sh path/to/Scrivora.zip" >&2
  exit 2
fi

for name in APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD; do
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required for notarization." >&2
    exit 2
  fi
done

xcrun notarytool submit "$APP_ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait
