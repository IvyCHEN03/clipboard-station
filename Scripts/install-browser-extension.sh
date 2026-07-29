#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/browser-extension/image-collector"
TARGET_DIR="${LINGGAN_EXTENSION_DIR:-$HOME/Library/Application Support/ClipboardStation/BrowserExtension}"
MODE="${1:---copy-only}"

if [[ "$MODE" != "--copy-only" && "$MODE" != "--reveal" ]]; then
  echo "Usage: $0 [--copy-only|--reveal]" >&2
  exit 2
fi

required_files=(
  manifest.json
  background.js
  content.js
  offscreen.js
  styles.css
)

mkdir -p "$TARGET_DIR"

for file in "${required_files[@]}"; do
  if [[ ! -f "$SOURCE_DIR/$file" ]]; then
    echo "Missing browser extension file: $SOURCE_DIR/$file" >&2
    exit 1
  fi
  cp "$SOURCE_DIR/$file" "$TARGET_DIR/$file"
done

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$TARGET_DIR/manifest.json")"

echo "Linggan Image Collector $version copied to:"
echo "$TARGET_DIR"

if [[ "$MODE" == "--reveal" ]]; then
  open -R "$TARGET_DIR/manifest.json"
  open -a "Google Chrome" "chrome://extensions/" >/dev/null 2>&1 || true
fi

echo "First repair: remove the old unpacked extension, then Load unpacked from the directory above."
echo "Later updates: run this script again, then click Reload on the same extension card."
