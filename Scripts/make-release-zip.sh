#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ClipboardStation.app"
DIST_DIR="$ROOT_DIR/.build/dist"
RAW_VERSION="${1:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
VERSION="${RAW_VERSION#v}"
TAG_VERSION="v$VERSION"
ZIP_PATH="$DIST_DIR/Linggan-Floating-Ball-$TAG_VERSION.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

cd "$ROOT_DIR"
./Scripts/package-app.sh

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$CHECKSUM_PATH"
)

echo "$ZIP_PATH"
