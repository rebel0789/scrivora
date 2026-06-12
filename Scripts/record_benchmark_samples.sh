#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-BenchmarkSamples}"
MANIFEST="$OUT_DIR/manifest.csv"
mkdir -p "$OUT_DIR"

if [[ ! -f "$MANIFEST" ]]; then
  printf 'id,audio,reference\n' >"$MANIFEST"
fi

echo "Recording samples into $OUT_DIR"
echo "Press Ctrl+C when done."
echo

index=1
while [[ -e "$OUT_DIR/sample-$(printf '%02d' "$index").wav" ]]; do
  index=$((index + 1))
done

while true; do
  sample_id="sample-$(printf '%02d' "$index")"
  audio_path="$OUT_DIR/$sample_id.wav"
  printf 'Reference text for %s: ' "$sample_id"
  IFS= read -r reference
  if [[ -z "${reference// }" ]]; then
    echo "Empty reference; stopping."
    break
  fi

  printf 'Duration seconds [6]: '
  IFS= read -r duration
  duration="${duration:-6}"

  echo "Recording $sample_id for ${duration}s."
  echo "Tip: speak naturally, including slang and pauses you actually use."
  if command -v sox >/dev/null 2>&1; then
    sox -d -r 16000 -c 1 -b 16 "$audio_path" trim 0 "$duration"
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg_device="${LOCALVOICEFLOW_FFMPEG_AUDIO_DEVICE:-:0}"
    ffmpeg -hide_banner -loglevel error -y \
      -f avfoundation \
      -i "$ffmpeg_device" \
      -t "$duration" \
      -ar 16000 \
      -ac 1 \
      -sample_fmt s16 \
      "$audio_path"
  else
    echo "Install sox or ffmpeg to record samples." >&2
    exit 1
  fi
  printf '%s,%s,%s\n' "$sample_id" "$audio_path" "$(printf '%s' "$reference" | sed 's/"/""/g; s/.*/"&"/')" >>"$MANIFEST"
  echo "Saved $audio_path"
  echo
  index=$((index + 1))
done

echo "Manifest: $MANIFEST"
