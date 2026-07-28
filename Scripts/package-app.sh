#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ClipboardStation.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ROOT_MARKER="$ROOT_DIR/.build/.linggan-source-root"

cd "$ROOT_DIR"

if [[ -d "$ROOT_DIR/.build" ]]; then
  PREVIOUS_ROOT="$(cat "$ROOT_MARKER" 2>/dev/null || true)"
  if [[ "$PREVIOUS_ROOT" != "$ROOT_DIR" ]]; then
    echo "Source checkout moved; clearing stale SwiftPM build cache."
    swift package clean
  fi
fi

swift build -c release
mkdir -p "$ROOT_DIR/.build"
printf "%s\n" "$ROOT_DIR" > "$ROOT_MARKER"
swift "$ROOT_DIR/Scripts/generate-icon.swift"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/ClipboardStation" "$MACOS_DIR/ClipboardStation"
chmod +x "$MACOS_DIR/ClipboardStation"
cp "$ROOT_DIR/BundleResources/Info.plist" "$CONTENTS_DIR/Info.plist"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"
cp "$ROOT_DIR/BundleResources/InspirationBubble.icns" "$RESOURCES_DIR/InspirationBubble.icns"
codesign --force --deep --sign - --identifier com.local.clipboard-station "$APP_DIR"

echo "Built $APP_DIR"
