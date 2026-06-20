#!/usr/bin/env bash
set -euo pipefail

ARTIFACT="${1:-}"

if [[ -z "$ARTIFACT" || ! -f "$ARTIFACT" ]]; then
  echo "Usage: Scripts/notarize_release_app.sh path/to/Scrivora.zip-or-dmg" >&2
  exit 2
fi

if [[ -z "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
  echo "NOTARYTOOL_KEYCHAIN_PROFILE is required." >&2
  echo "Create one with: xcrun notarytool store-credentials <profile-name> --apple-id <apple-id> --team-id <team-id>" >&2
  exit 2
fi

xcrun notarytool submit "$ARTIFACT" \
  --keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE" \
  --wait
