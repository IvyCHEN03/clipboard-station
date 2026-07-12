#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ClipboardStation.app"
DIST_DIR="$ROOT_DIR/.build/dist"
VERSION="${1:-$(cat "$ROOT_DIR/VERSION")}"
ZIP_PATH="$DIST_DIR/Linggan-Floating-Ball-$VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"
./Scripts/package-app.sh

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$CHECKSUM_PATH"
)

echo "$ZIP_PATH"
