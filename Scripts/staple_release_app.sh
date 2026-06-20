#!/usr/bin/env bash
set -euo pipefail

ARTIFACT="${1:-}"

if [[ -z "$ARTIFACT" || ! -e "$ARTIFACT" ]]; then
  echo "Usage: Scripts/staple_release_app.sh path/to/Scrivora.app-or-dmg" >&2
  exit 2
fi

xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
