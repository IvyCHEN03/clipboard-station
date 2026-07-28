#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClipboardStation.app"
BUILT_APP="$ROOT_DIR/.build/$APP_NAME"
INSTALL_DIR="${LINGGAN_INSTALL_DIR:-$ROOT_DIR}"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.local.clipboard-station.agent.plist"

cd "$ROOT_DIR"

./Scripts/package-app.sh

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALLED_APP"

launchctl bootout "gui/$(id -u)/com.local.clipboard-station.agent" >/dev/null 2>&1 || true
# Multiple installed app names share this executable. Stop every stale copy so
# Finder, the menu bar, and the launch agent cannot keep an older binary alive.
pkill -x "ClipboardStation" >/dev/null 2>&1 || true
open -na "$INSTALLED_APP"

echo "Installed $INSTALLED_APP"
echo "Launch at login is controlled by the app setting."
echo "Move the repository later? Re-run this script to refresh the launch agent path."
echo "The floating bubble should appear shortly."
