#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  echo "DEVELOPER_ID_APPLICATION is required for release packaging." >&2
  echo "Example: export DEVELOPER_ID_APPLICATION='Developer ID Application: Example, Inc. (TEAMID)'" >&2
  exit 2
fi

if ! command -v codesign >/dev/null 2>&1; then
  echo "codesign is required." >&2
  exit 2
fi

echo "Release packaging is intentionally gated."
echo "Next implementation step: package with hardened runtime, sign with:"
echo "  $DEVELOPER_ID_APPLICATION"
echo "Then notarize with Scripts/notarize_release_app.sh and staple with Scripts/staple_release_app.sh."
echo
echo "For now, create the development bundle with:"
echo "  Scripts/package_dev_app.sh"
exit 2
