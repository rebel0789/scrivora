#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-base.en-q5_1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT/Vendor"
WHISPER_DIR="$VENDOR_DIR/whisper.cpp"
APP_SUPPORT="$HOME/Library/Application Support/LocalVoiceFlow/Models"

mkdir -p "$VENDOR_DIR" "$APP_SUPPORT"

if command -v whisper-cli >/dev/null 2>&1; then
  echo "Using existing whisper-cli: $(command -v whisper-cli)"
else
  if command -v brew >/dev/null 2>&1; then
    brew install whisper-cpp
  else
    if ! command -v cmake >/dev/null 2>&1; then
      echo "cmake is required to build whisper.cpp from source. Install cmake or Homebrew whisper-cpp." >&2
      exit 1
    fi

    if [[ ! -d "$WHISPER_DIR/.git" ]]; then
      git clone https://github.com/ggml-org/whisper.cpp "$WHISPER_DIR"
    fi

    cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
    cmake --build "$WHISPER_DIR/build" --config Release -j"$(sysctl -n hw.ncpu)"
    echo "Built whisper-cli: $WHISPER_DIR/build/bin/whisper-cli"
  fi
fi

"$ROOT/Scripts/download_whisper_model.sh" "$MODEL"
echo "Whisper executable path: $(command -v whisper-cli || echo "$WHISPER_DIR/build/bin/whisper-cli")"
