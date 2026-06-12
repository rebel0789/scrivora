#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-v3}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUIDAUDIO_DIR="${FLUIDAUDIO_SOURCE_DIR:-$ROOT/Vendor/FluidAudio}"
FLUIDAUDIO_TAG="${FLUIDAUDIO_TAG:-v0.15.2}"
MODELS_ROOT="$HOME/Library/Application Support/FluidAudio/Models"

case "$VERSION" in
  v2|v3|110m) ;;
  *)
    echo "Usage: $0 [v2|v3|110m]" >&2
    exit 1
    ;;
esac

case "$VERSION" in
  v2) MODEL_DIR="$MODELS_ROOT/parakeet-tdt-0.6b-v2" ;;
  v3) MODEL_DIR="$MODELS_ROOT/parakeet-tdt-0.6b-v3" ;;
  110m) MODEL_DIR="$MODELS_ROOT/parakeet-tdt-ctc-110m" ;;
esac

required_model_paths() {
  case "$VERSION" in
    v2)
      printf '%s\n' \
        "Preprocessor.mlmodelc/coremldata.bin" \
        "Encoder.mlmodelc/coremldata.bin" \
        "Decoder.mlmodelc/coremldata.bin" \
        "JointDecision.mlmodelc/coremldata.bin" \
        "parakeet_vocab.json"
      ;;
    v3)
      printf '%s\n' \
        "Preprocessor.mlmodelc/coremldata.bin" \
        "Encoder.mlmodelc/coremldata.bin" \
        "Decoder.mlmodelc/coremldata.bin" \
        "JointDecisionv3.mlmodelc/coremldata.bin" \
        "parakeet_vocab.json"
      ;;
    110m)
      printf '%s\n' \
        "Preprocessor.mlmodelc/coremldata.bin" \
        "Decoder.mlmodelc/coremldata.bin" \
        "JointDecision.mlmodelc/coremldata.bin" \
        "parakeet_vocab.json"
      ;;
  esac
}

model_cache_complete() {
  local relative_path
  while IFS= read -r relative_path; do
    [[ -e "$MODEL_DIR/$relative_path" ]] || return 1
  done < <(required_model_paths)
}

if [[ -d "$MODEL_DIR" ]] && ! model_cache_complete; then
  echo "Removing incomplete FluidAudio model cache: $MODEL_DIR"
  rm -rf "$MODEL_DIR"
fi

if command -v fluidaudiocli >/dev/null 2>&1; then
  CLI="$(command -v fluidaudiocli)"
else
  if [[ ! -d "$FLUIDAUDIO_DIR/.git" ]]; then
    mkdir -p "$(dirname "$FLUIDAUDIO_DIR")"
    git clone --branch "$FLUIDAUDIO_TAG" --depth 1 https://github.com/FluidInference/FluidAudio.git "$FLUIDAUDIO_DIR"
  fi

  swift build --package-path "$FLUIDAUDIO_DIR" -c release --product fluidaudiocli
  CLI="$FLUIDAUDIO_DIR/.build/release/fluidaudiocli"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

say -v Samantha "local voice flow model setup" -o "$TMP_DIR/setup.aiff"
afconvert -f WAVE -d LEI16@16000 "$TMP_DIR/setup.aiff" "$TMP_DIR/setup.wav"

echo "Using FluidAudio CLI: $CLI"
echo "FluidAudio model directory: $MODEL_DIR"
echo "Downloading/loading Parakeet $VERSION through FluidAudio..."
"$CLI" transcribe "$TMP_DIR/setup.wav" --model-version "$VERSION" >/dev/null

if ! model_cache_complete; then
  echo "FluidAudio download finished but the model cache is still incomplete: $MODEL_DIR" >&2
  exit 1
fi

echo "Parakeet $VERSION model is ready at: $MODEL_DIR"
