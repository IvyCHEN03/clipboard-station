#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/ClipboardStation"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.local.clipboard-station.agent.plist"
INSTALLED_APP="$HOME/Applications/ClipboardStation.app"

echo "Linggan Floating Ball doctor"
echo

echo "Swift:"
if command -v swift >/dev/null 2>&1; then
  swift --version | head -n 1
else
  echo "  missing"
fi

echo
echo "Repository:"
echo "  $ROOT_DIR"

echo
echo "Build:"
if [[ -d "$ROOT_DIR/.build/ClipboardStation.app" ]]; then
  echo "  packaged app exists: $ROOT_DIR/.build/ClipboardStation.app"
else
  echo "  packaged app missing; run ./Scripts/package-app.sh"
fi

echo
echo "Install:"
if [[ -d "$INSTALLED_APP" ]]; then
  echo "  installed app exists: $INSTALLED_APP"
else
  echo "  installed app missing; run ./Scripts/install-local.sh"
fi

echo
echo "Launch agent:"
if [[ -f "$LAUNCH_AGENT" ]]; then
  echo "  exists: $LAUNCH_AGENT"
  AGENT_TARGET="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$LAUNCH_AGENT" 2>/dev/null || true)"
  if [[ -n "$AGENT_TARGET" ]]; then
    echo "  target: $AGENT_TARGET"
    if [[ -x "$AGENT_TARGET" ]]; then
      echo "  target exists: yes"
    else
      echo "  target exists: no"
      echo "  repair: run ./Scripts/install-local.sh"
    fi
  fi
  if launchctl print "gui/$(id -u)/com.local.clipboard-station.agent" >/dev/null 2>&1; then
    echo "  loaded: yes"
  else
    echo "  loaded: no"
  fi
else
  echo "  missing"
fi

echo
echo "Process:"
if pgrep -fl "ClipboardStation" >/dev/null 2>&1; then
  pgrep -fl "ClipboardStation"
else
  echo "  not running"
fi

echo
echo "Local data:"
if [[ -d "$APP_SUPPORT" ]]; then
  echo "  exists: $APP_SUPPORT"
else
  echo "  not created yet"
fi

echo
echo "If the floating bubble is not visible:"
echo "  1. Run ./Scripts/install-local.sh"
echo "  2. Check macOS Accessibility permission if paste automation fails"
echo "  3. Open the menu bar icon or relaunch $INSTALLED_APP"
