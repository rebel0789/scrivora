#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${1:-$ROOT/.build/release-artifacts}"
OUTPUT="${2:-$RELEASE_DIR/SHA256SUMS.txt}"
shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))

if [[ ! -d "$RELEASE_DIR" ]]; then
  echo "Release artifact directory not found: $RELEASE_DIR" >&2
  exit 2
fi

FILES=()
if [[ "$#" -gt 0 ]]; then
  for file in "$@"; do
    FILES+=("$file")
  done
else
  while IFS= read -r file; do
    FILES+=("$file")
  done < <(
    find "$RELEASE_DIR" -maxdepth 1 -type f \
      \( -name '*.dmg' -o -name '*.zip' -o -name '*.json' \) \
      ! -name 'SHA256SUMS.txt' \
      | sort
  )
fi

if [[ "${#FILES[@]}" -eq 0 ]]; then
  echo "No release artifacts found in $RELEASE_DIR" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUTPUT")"
: > "$OUTPUT"

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Release artifact not found: $file" >&2
    exit 2
  fi
  digest="$(shasum -a 256 "$file" | awk '{print $1}')"
  printf '%s  %s\n' "$digest" "$(basename "$file")" >> "$OUTPUT"
done

echo "$OUTPUT"
