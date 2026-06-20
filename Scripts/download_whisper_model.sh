#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-base.en-q5_1}"
APP_SUPPORT="${LOCALVOICEFLOW_MODEL_DIR:-$HOME/Library/Application Support/LocalVoiceFlow/Models}"
FILENAME="ggml-${MODEL}.bin"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${FILENAME}?download=true"
EXPECTED_SHA256="${SCRIVORA_MODEL_SHA256:-}"

if [[ -z "$EXPECTED_SHA256" ]]; then
  case "$MODEL" in
    tiny.en-q5_1) EXPECTED_SHA256="c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b" ;;
    base.en-q5_1) EXPECTED_SHA256="4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f" ;;
    small.en-q5_1) EXPECTED_SHA256="bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30" ;;
    *)
      echo "No pinned SHA-256 is configured for $MODEL. Set SCRIVORA_MODEL_SHA256 to download a custom model." >&2
      exit 2
      ;;
  esac
fi

mkdir -p "$APP_SUPPORT"

DEST="$APP_SUPPORT/$FILENAME"
TMP="$DEST.part"

if [[ -s "$DEST" ]]; then
  echo "Model already exists: $DEST"
  exit 0
fi

echo "Downloading $FILENAME"
echo "Destination: $DEST"
curl -L --fail --progress-bar "$URL" -o "$TMP"
ACTUAL_SHA256="$(shasum -a 256 "$TMP" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  rm -f "$TMP"
  echo "SHA-256 mismatch for $FILENAME" >&2
  echo "Expected: $EXPECTED_SHA256" >&2
  echo "Actual:   $ACTUAL_SHA256" >&2
  exit 1
fi
mv "$TMP" "$DEST"
echo "$DEST"
