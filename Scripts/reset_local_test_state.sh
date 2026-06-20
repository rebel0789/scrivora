#!/usr/bin/env bash
set -euo pipefail

APP="/Applications/Scrivora.app"
LEGACY_APP="/Applications/LocalVoiceFlow.app"
APP_SUPPORT="$HOME/Library/Application Support/LocalVoiceFlow"
SCRIVORA_SUPPORT="$HOME/Library/Application Support/Scrivora"
FLUIDAUDIO_MODELS="$HOME/Library/Application Support/FluidAudio/Models"
DO_DELETE=0
REMOVE_APP=0
REMOVE_APP_SUPPORT=0
REMOVE_FLUIDAUDIO=0

usage() {
  cat <<'USAGE'
Usage: Scripts/reset_local_test_state.sh [--delete] [--app] [--app-support] [--fluidaudio-cache]

Default is dry-run. Nothing is deleted unless --delete is present.

Examples:
  Scripts/reset_local_test_state.sh
  Scripts/reset_local_test_state.sh --delete --app --app-support
  Scripts/reset_local_test_state.sh --delete --fluidaudio-cache
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --delete) DO_DELETE=1 ;;
    --app) REMOVE_APP=1 ;;
    --app-support) REMOVE_APP_SUPPORT=1 ;;
    --fluidaudio-cache) REMOVE_FLUIDAUDIO=1 ;;
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

delete_path() {
  local path="$1"
  local label="$2"
  if [[ ! -e "$path" ]]; then
    echo "Not present: $label ($path)"
    return
  fi
  if [[ "$DO_DELETE" -eq 1 ]]; then
    rm -rf "$path"
    echo "Deleted: $label ($path)"
  else
    echo "Would delete: $label ($path)"
  fi
}

if [[ "$REMOVE_APP" -eq 1 ]]; then
  delete_path "$APP" "installed Scrivora app"
  delete_path "$LEGACY_APP" "legacy LocalVoiceFlow app"
else
  echo "Skipping installed app. Pass --app to include it."
fi

if [[ "$REMOVE_APP_SUPPORT" -eq 1 ]]; then
  delete_path "$APP_SUPPORT" "LocalVoiceFlow app support data"
  delete_path "$SCRIVORA_SUPPORT" "Scrivora app support data"
else
  echo "Skipping app support data. Pass --app-support to include it."
fi

if [[ "$REMOVE_FLUIDAUDIO" -eq 1 ]]; then
  delete_path "$FLUIDAUDIO_MODELS" "FluidAudio model cache"
else
  echo "Skipping FluidAudio model cache. Pass --fluidaudio-cache to include it."
fi

if [[ "$DO_DELETE" -ne 1 ]]; then
  echo
  echo "Dry run only. Add --delete with explicit targets to remove files."
fi
