#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/LocalVoiceFlow"
TMPDIR_ROOT="${TMPDIR:-/tmp}"

echo "Sensitive file audit"
echo "Repo: $ROOT"
echo "App support: $APP_SUPPORT"
echo

echo "Signing material candidates:"
find "$ROOT" "$APP_SUPPORT" \
  \( -path "$ROOT/.git" -o -path "$ROOT/.build/checkouts" -o -path "$ROOT/.build/repositories" \) -prune -o \
  -type f \( \
    -name '*.p12' -o \
    -name '*.cer' -o \
    -name '*.key' -o \
    -name '*.pem' -o \
    -name '*.mobileprovision' -o \
    -name '*.keychain' -o \
    -name '*.keychain-db' -o \
    -iname '*password*' \
  \) -print 2>/dev/null || true

echo
echo "Scrivora audio/temp candidates outside model caches:"
find "$APP_SUPPORT" "$TMPDIR_ROOT" \
  \( -name 'TemporaryItems' -o -path '*/com.apple.*' \) -prune -o \
  -type f \( \
    -name 'LocalVoiceFlow-*.wav' -o \
    -name 'LocalVoiceFlow-*.txt' -o \
    -name 'Scrivora-*.wav' -o \
    -name 'sample.wav' -o \
    -name 'sample.aiff' \
  \) \
  -not -path '*/Models/*' \
  -not -path '*/FluidAudio/Models/*' \
  -print 2>/dev/null || true

echo
echo "Local text data stores:"
find "$APP_SUPPORT" \
  -type f \( -name 'history.json' -o -name 'corrections.json' -o -name 'dictation-performance.jsonl' -o -name 'settings.json' \) \
  -print 2>/dev/null || true

echo
echo "Audit complete. Paths are printed only; file contents are not read."
