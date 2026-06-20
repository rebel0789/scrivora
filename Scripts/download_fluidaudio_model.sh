#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-v3}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUIDAUDIO_DIR="${FLUIDAUDIO_SOURCE_DIR:-$ROOT/Vendor/FluidAudio}"
FLUIDAUDIO_REPOSITORY="https://github.com/FluidInference/FluidAudio.git"
EXPECTED_FLUIDAUDIO_REVISION="${FLUIDAUDIO_REVISION:-}"
MODELS_ROOT="$HOME/Library/Application Support/FluidAudio/Models"

case "$VERSION" in
  v2|v3|110m) ;;
  *)
    echo "Usage: $0 [v2|v3|110m]" >&2
    exit 1
    ;;
esac

if [[ -z "$EXPECTED_FLUIDAUDIO_REVISION" ]]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to read the pinned FluidAudio revision from Package.resolved." >&2
    exit 2
  fi
  EXPECTED_FLUIDAUDIO_REVISION="$(python3 - "$ROOT/Package.resolved" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
for pin in data.get("pins", []):
    if pin.get("identity") == "fluidaudio":
        revision = pin.get("state", {}).get("revision")
        if revision:
            print(revision)
            raise SystemExit(0)
raise SystemExit("FluidAudio revision was not found in Package.resolved")
PY
)"
fi

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

prepare_fluidaudio_source() {
  if [[ -n "${FLUIDAUDIO_SOURCE_DIR:-}" && "${FLUIDAUDIO_ALLOW_LOCAL_SOURCE:-0}" != "1" ]]; then
    echo "FLUIDAUDIO_SOURCE_DIR overrides are disabled by default. Set FLUIDAUDIO_ALLOW_LOCAL_SOURCE=1 and use a git checkout at the pinned revision." >&2
    exit 2
  fi

  if [[ ! -d "$FLUIDAUDIO_DIR/.git" ]]; then
    rm -rf "$FLUIDAUDIO_DIR"
    mkdir -p "$FLUIDAUDIO_DIR"
    git -C "$FLUIDAUDIO_DIR" init
    git -C "$FLUIDAUDIO_DIR" remote add origin "$FLUIDAUDIO_REPOSITORY"
  fi

  git -C "$FLUIDAUDIO_DIR" fetch --depth 1 origin "$EXPECTED_FLUIDAUDIO_REVISION"
  git -C "$FLUIDAUDIO_DIR" checkout --detach "$EXPECTED_FLUIDAUDIO_REVISION"

  local actual_revision
  actual_revision="$(git -C "$FLUIDAUDIO_DIR" rev-parse HEAD)"
  if [[ "$actual_revision" != "$EXPECTED_FLUIDAUDIO_REVISION" ]]; then
    echo "FluidAudio checkout revision mismatch." >&2
    echo "Expected: $EXPECTED_FLUIDAUDIO_REVISION" >&2
    echo "Actual:   $actual_revision" >&2
    exit 1
  fi
}

if [[ -d "$MODEL_DIR" ]] && ! model_cache_complete; then
  echo "Removing incomplete FluidAudio model cache: $MODEL_DIR"
  rm -rf "$MODEL_DIR"
fi

if command -v fluidaudiocli >/dev/null 2>&1; then
  CLI="$(command -v fluidaudiocli)"
else
  prepare_fluidaudio_source

  swift build --package-path "$FLUIDAUDIO_DIR" -c release --product fluidaudiocli
  CLI="$FLUIDAUDIO_DIR/.build/release/fluidaudiocli"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

say -v Samantha "local voice flow model setup" -o "$TMP_DIR/setup.aiff"
afconvert -f WAVE -d LEI16@16000 "$TMP_DIR/setup.aiff" "$TMP_DIR/setup.wav"

echo "Using FluidAudio CLI: $CLI"
echo "Verified FluidAudio revision: $EXPECTED_FLUIDAUDIO_REVISION"
echo "FluidAudio model directory: $MODEL_DIR"
echo "Downloading/loading Parakeet $VERSION through FluidAudio..."
"$CLI" transcribe "$TMP_DIR/setup.wav" --model-version "$VERSION" >/dev/null

if ! model_cache_complete; then
  echo "FluidAudio download finished but the model cache is still incomplete: $MODEL_DIR" >&2
  exit 1
fi

echo "Parakeet $VERSION model is ready at: $MODEL_DIR"
