#!/usr/bin/env bash
set -euo pipefail

APP="${1:-/Applications/Scrivora.app}"

if [[ ! -d "$APP" ]]; then
  echo "App not found: $APP" >&2
  exit 2
fi

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | sed -n '/Identifier=/p;/Authority=/p;/TeamIdentifier=/p;/Runtime Version=/p'
spctl --assess --type execute --verbose=4 "$APP"
