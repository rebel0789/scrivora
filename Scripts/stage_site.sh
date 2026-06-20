#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="${SCRIVORA_SITE_DIR:-$ROOT/.site}"

rm -rf "$SITE_DIR"
mkdir -p "$SITE_DIR"

copy_file() {
  local path="$1"
  if [[ -f "$ROOT/$path" ]]; then
    mkdir -p "$SITE_DIR/$(dirname "$path")"
    cp "$ROOT/$path" "$SITE_DIR/$path"
  fi
}

copy_dir() {
  local path="$1"
  if [[ -d "$ROOT/$path" ]]; then
    mkdir -p "$SITE_DIR/$(dirname "$path")"
    cp -R "$ROOT/$path" "$SITE_DIR/$path"
  fi
}

copy_file "index.html"
copy_file "tokens.css"
copy_file "CNAME"
copy_file ".nojekyll"
copy_file "robots.txt"
copy_file "sitemap.xml"
copy_file "site.webmanifest"
copy_dir "Assets"
copy_dir "releases"
copy_dir "updates"

cat > "$SITE_DIR/vercel.json" <<'JSON'
{
  "cleanUrls": true,
  "trailingSlash": false,
  "headers": [
    {
      "source": "/Assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    },
    {
      "source": "/updates/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=60, must-revalidate"
        }
      ]
    }
  ]
}
JSON

echo "$SITE_DIR"
