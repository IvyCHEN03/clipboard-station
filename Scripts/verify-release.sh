#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: ./Scripts/verify-release.sh path/to/Linggan-Floating-Ball-vX.Y.Z.zip" >&2
  exit 2
fi

ZIP_PATH="$1"
CHECKSUM_PATH="$ZIP_PATH.sha256"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Release zip not found: $ZIP_PATH" >&2
  exit 1
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
  echo "Checksum file not found: $CHECKSUM_PATH" >&2
  exit 1
fi

DIST_DIR="$(cd "$(dirname "$ZIP_PATH")" && pwd)"
ZIP_NAME="$(basename "$ZIP_PATH")"

echo "== Checksum =="
(
  cd "$DIST_DIR"
  shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)

echo
echo "== Zip contents =="
ZIP_LIST="$(unzip -l "$ZIP_PATH")"
if ! grep -q "ClipboardStation.app/Contents/MacOS/ClipboardStation" <<< "$ZIP_LIST"; then
  echo "ClipboardStation executable not found inside zip." >&2
  exit 1
fi
echo "ok: $ZIP_NAME contains ClipboardStation.app"

echo
echo "Release archive verified."
