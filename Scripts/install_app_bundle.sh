#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT/.build/Scrivora.app"
DEFAULT_INSTALL_DIR="/Applications"
if [[ ! -w "$DEFAULT_INSTALL_DIR" ]]; then
  DEFAULT_INSTALL_DIR="$HOME/Applications"
fi
INSTALL_DIR="${LOCALVOICEFLOW_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
INSTALLED_APP="$INSTALL_DIR/Scrivora.app"

pkill -f "$SOURCE_APP/Contents/MacOS/LocalVoiceFlowApp" >/dev/null 2>&1 || true
pkill -f "$INSTALLED_APP/Contents/MacOS/LocalVoiceFlowApp" >/dev/null 2>&1 || true
pkill -f "/Applications/LocalVoiceFlow.app/Contents/MacOS/LocalVoiceFlowApp" >/dev/null 2>&1 || true
pkill -x LocalVoiceFlowApp >/dev/null 2>&1 || true
pkill -f '/whisper-server -m .*/Library/Application Support/LocalVoiceFlow/Models/ggml-.*\\.bin' >/dev/null 2>&1 || true

"$ROOT/Scripts/package_app_bundle.sh" >/dev/null

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
if [[ "$INSTALLED_APP" != "$HOME/Applications/LocalVoiceFlow.app" ]]; then
  rm -rf "$HOME/Applications/LocalVoiceFlow.app"
fi
if [[ "$INSTALLED_APP" != "/Applications/LocalVoiceFlow.app" && -w "/Applications" ]]; then
  rm -rf "/Applications/LocalVoiceFlow.app"
fi
cp -R "$SOURCE_APP" "$INSTALLED_APP"
xattr -dr com.apple.quarantine "$INSTALLED_APP" >/dev/null 2>&1 || true

echo "$INSTALLED_APP"
