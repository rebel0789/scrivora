#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-base.en-q5_1}"
APP_SUPPORT="${LOCALVOICEFLOW_MODEL_DIR:-$HOME/Library/Application Support/LocalVoiceFlow/Models}"
FILENAME="ggml-${MODEL}.bin"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${FILENAME}?download=true"

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
mv "$TMP" "$DEST"
echo "$DEST"
