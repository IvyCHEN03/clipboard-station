#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ClipboardStation.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build -c release
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
