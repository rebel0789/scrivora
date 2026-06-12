#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"

if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Usage: Scripts/staple_release_app.sh path/to/Scrivora.app" >&2
  exit 2
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
