#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/Scrivora.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
SIGNING_DIR="$HOME/Library/Application Support/LocalVoiceFlow/Signing"
LOCAL_KEYCHAIN="$SIGNING_DIR/LocalVoiceFlowSigning.keychain-db"
LOCAL_KEYCHAIN_PASSWORD_FILE="$SIGNING_DIR/keychain-password.txt"
DEFAULT_IDENTITY="LocalVoiceFlow Development"

cd "$ROOT"
swift build -c release --product LocalVoiceFlowApp

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$ROOT/.build/release/LocalVoiceFlowApp" "$MACOS/LocalVoiceFlowApp"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>LocalVoiceFlowApp</string>
  <key>CFBundleIdentifier</key>
  <string>app.localvoiceflow.mvp</string>
  <key>CFBundleName</key>
  <string>Scrivora</string>
  <key>CFBundleDisplayName</key>
  <string>Scrivora</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Scrivora records microphone audio to transcribe speech locally on this Mac.</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${LOCALVOICEFLOW_CODESIGN_IDENTITY:-}"
  SIGN_KEYCHAIN="${LOCALVOICEFLOW_CODESIGN_KEYCHAIN:-}"

  if [[ -z "$SIGN_IDENTITY" && -x "$ROOT/Scripts/create_local_codesign_identity.sh" ]]; then
    SIGN_IDENTITY="$("$ROOT/Scripts/create_local_codesign_identity.sh")"
    SIGN_KEYCHAIN="$LOCAL_KEYCHAIN"
  fi

  if [[ -n "$SIGN_IDENTITY" && -n "$SIGN_KEYCHAIN" && -f "$SIGN_KEYCHAIN" ]]; then
    if [[ -f "$LOCAL_KEYCHAIN_PASSWORD_FILE" ]]; then
      security unlock-keychain -p "$(cat "$LOCAL_KEYCHAIN_PASSWORD_FILE")" "$SIGN_KEYCHAIN" >/dev/null 2>&1 || true
    fi
    EXISTING_KEYCHAINS="$(security list-keychains -d user | sed 's/[" ]//g' | tr '\n' ' ')"
    security list-keychains -d user -s "$SIGN_KEYCHAIN" $EXISTING_KEYCHAINS
    if codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"; then
      echo "Signed with $SIGN_IDENTITY"
    else
      codesign --force --deep --sign - "$APP"
      echo "Signed ad-hoc after local identity signing failed"
    fi
  elif [[ -n "$SIGN_IDENTITY" ]]; then
    if codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"; then
      echo "Signed with $SIGN_IDENTITY"
    else
      codesign --force --deep --sign - "$APP"
      echo "Signed ad-hoc after configured identity signing failed"
    fi
  else
    codesign --force --deep --sign - "$APP"
    echo "Signed ad-hoc"
  fi
fi

echo "$APP"
