#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ClipboardStation.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.local.clipboard-station.agent.plist"

launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
pkill -f "ClipboardStation.app/Contents/MacOS/ClipboardStation" >/dev/null 2>&1 || true
rm -f "$LAUNCH_AGENT"
rm -rf "$INSTALLED_APP"

echo "Uninstalled Linggan Floating Ball from $INSTALLED_APP"
echo "Local snippet data was not removed."
echo "To remove local data too, delete:"
echo "  $HOME/Library/Application Support/ClipboardStation"
