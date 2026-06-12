#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_DIR="$HOME/Library/Application Support/LocalVoiceFlow/Signing"
NEW_PARENT="${LOCALVOICEFLOW_DEV_SIGNING_DIR:-$ROOT/.build/dev-signing}"
ACTION="move"

usage() {
  cat <<'USAGE'
Usage: Scripts/clean_dev_signing_material.sh [--move|--delete|--dry-run]

Moves or deletes the old development signing folder from:
  ~/Library/Application Support/LocalVoiceFlow/Signing

Default action:
  --move    Move it under .build/dev-signing, or a timestamped subfolder if a keychain already exists there
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --move) ACTION="move" ;;
    --delete) ACTION="delete" ;;
    --dry-run) ACTION="dry-run" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$OLD_DIR" ]]; then
  echo "No old signing folder found at: $OLD_DIR"
  exit 0
fi

case "$ACTION" in
  dry-run)
    echo "Would move or delete old signing folder: $OLD_DIR"
    find "$OLD_DIR" -maxdepth 1 -type f -print
    ;;
  move)
    mkdir -p "$NEW_PARENT"
    chmod 700 "$NEW_PARENT"
    if [[ ! -e "$NEW_PARENT/LocalVoiceFlowSigning.keychain-db" ]]; then
      shopt -s dotglob nullglob
      mv "$OLD_DIR"/* "$NEW_PARENT"/
      rmdir "$OLD_DIR"
      chmod -R go-rwx "$NEW_PARENT"
      echo "Moved old signing material to: $NEW_PARENT"
    else
      DEST="$NEW_PARENT/migrated-from-app-support-$(date +%Y%m%d-%H%M%S)"
      mv "$OLD_DIR" "$DEST"
      chmod -R go-rwx "$DEST"
      echo "Moved old signing material to: $DEST"
    fi
    ;;
  delete)
    rm -rf "$OLD_DIR"
    echo "Deleted old signing folder: $OLD_DIR"
    ;;
esac
