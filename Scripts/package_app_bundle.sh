#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/Scrivora.app"
LEGACY_APP="$ROOT/.build/LocalVoiceFlowApp.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
SIGNING_DIR="${LOCALVOICEFLOW_DEV_SIGNING_DIR:-$ROOT/.build/dev-signing}"
LOCAL_KEYCHAIN="$SIGNING_DIR/LocalVoiceFlowSigning.keychain-db"
LOCAL_KEYCHAIN_PASSWORD_FILE="$SIGNING_DIR/keychain-password.txt"
DEFAULT_IDENTITY="LocalVoiceFlow Development"
BUNDLE_ID="${SCRIVORA_BUNDLE_ID:-me.scrivora.app}"
APP_VERSION="${SCRIVORA_VERSION:-0.4.1}"
UPDATE_MANIFEST_URL="${SCRIVORA_UPDATE_MANIFEST_URL:-}"
UPDATE_DEVELOPER_TEAM_ID="${SCRIVORA_UPDATE_DEVELOPER_TEAM_ID:-}"

xml_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g"
}

BUNDLE_ID_XML="$(printf '%s' "$BUNDLE_ID" | xml_escape)"
APP_VERSION_XML="$(printf '%s' "$APP_VERSION" | xml_escape)"
UPDATE_MANIFEST_URL_XML="$(printf '%s' "$UPDATE_MANIFEST_URL" | xml_escape)"
UPDATE_DEVELOPER_TEAM_ID_XML="$(printf '%s' "$UPDATE_DEVELOPER_TEAM_ID" | xml_escape)"

cd "$ROOT"
swift build -c release --product LocalVoiceFlowApp

if [[ ! -f "$ROOT/Assets/ScrivoraIcon.icns" || ! -f "$ROOT/Assets/Brand/ScrivoraMenuBarTemplate.png" ]]; then
  swift "$ROOT/Scripts/generate_brand_assets.swift" >/dev/null
fi

pkill -f "$LEGACY_APP/Contents/MacOS/LocalVoiceFlowApp" >/dev/null 2>&1 || true
rm -rf "$APP" "$LEGACY_APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/LocalVoiceFlowApp" "$MACOS/LocalVoiceFlowApp"
cp "$ROOT/Assets/ScrivoraIcon.icns" "$RESOURCES/ScrivoraIcon.icns"
cp "$ROOT/Assets/Brand/ScrivoraMenuBarTemplate.png" "$RESOURCES/ScrivoraMenuBarTemplate.png"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>LocalVoiceFlowApp</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID_XML}</string>
  <key>CFBundleName</key>
  <string>Scrivora</string>
  <key>CFBundleDisplayName</key>
  <string>Scrivora</string>
  <key>CFBundleIconFile</key>
  <string>ScrivoraIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION_XML}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Scrivora records microphone audio to transcribe speech locally on this Mac.</string>
  <key>ScrivoraUpdateManifestURL</key>
  <string>${UPDATE_MANIFEST_URL_XML}</string>
  <key>ScrivoraUpdateDeveloperTeamID</key>
  <string>${UPDATE_DEVELOPER_TEAM_ID_XML}</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  SIGN_IDENTITY="${LOCALVOICEFLOW_CODESIGN_IDENTITY:-}"
  SIGN_KEYCHAIN="${LOCALVOICEFLOW_CODESIGN_KEYCHAIN:-}"

  if [[ -z "$SIGN_IDENTITY" && -x "$ROOT/Scripts/create_local_codesign_identity.sh" ]]; then
    SIGN_IDENTITY="$(LOCALVOICEFLOW_DEV_SIGNING_DIR="$SIGNING_DIR" "$ROOT/Scripts/create_local_codesign_identity.sh")"
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
