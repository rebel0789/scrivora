#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-base.en-q5_1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT/Vendor"
WHISPER_DIR="$VENDOR_DIR/whisper.cpp"
APP_SUPPORT="$HOME/Library/Application Support/LocalVoiceFlow/Models"
WHISPER_CPP_REPOSITORY="https://github.com/ggml-org/whisper.cpp"
WHISPER_CPP_REVISION="${WHISPER_CPP_REVISION:-23ee03506a91ac3d3f0071b40e66a430eebdfa1d}"

mkdir -p "$VENDOR_DIR" "$APP_SUPPORT"

prepare_whisper_cpp_source() {
  if [[ ! -d "$WHISPER_DIR/.git" ]]; then
    rm -rf "$WHISPER_DIR"
    mkdir -p "$WHISPER_DIR"
    git -C "$WHISPER_DIR" init
    git -C "$WHISPER_DIR" remote add origin "$WHISPER_CPP_REPOSITORY"
  fi

  git -C "$WHISPER_DIR" fetch --depth 1 origin "$WHISPER_CPP_REVISION"
  git -C "$WHISPER_DIR" checkout --detach "$WHISPER_CPP_REVISION"

  local actual_revision
  actual_revision="$(git -C "$WHISPER_DIR" rev-parse HEAD)"
  if [[ "$actual_revision" != "$WHISPER_CPP_REVISION" ]]; then
    echo "whisper.cpp checkout revision mismatch." >&2
    echo "Expected: $WHISPER_CPP_REVISION" >&2
    echo "Actual:   $actual_revision" >&2
    exit 1
  fi
}

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

    prepare_whisper_cpp_source

    cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release
    cmake --build "$WHISPER_DIR/build" --config Release -j"$(sysctl -n hw.ncpu)"
    echo "Verified whisper.cpp revision: $WHISPER_CPP_REVISION"
    echo "Built whisper-cli: $WHISPER_DIR/build/bin/whisper-cli"
  fi
fi

"$ROOT/Scripts/download_whisper_model.sh" "$MODEL"
echo "Whisper executable path: $(command -v whisper-cli || echo "$WHISPER_DIR/build/bin/whisper-cli")"
