#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/ClipboardStation"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.local.clipboard-station.agent.plist"
INSTALLED_APP="$HOME/Applications/ClipboardStation.app"
WARNINGS=0

ok() {
  echo "  OK   $1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  echo "  WARN $1"
}

info() {
  echo "  INFO $1"
}

echo "Linggan Floating Ball doctor"
echo "Privacy note: this script does not print clipboard contents, snippets, API keys, or encrypted local state."
echo

echo "Swift:"
if command -v swift >/dev/null 2>&1; then
  SWIFT_VERSION="$(swift --version 2>&1 | head -n 1)"
  ok "$SWIFT_VERSION"
else
  warn "Swift is missing. Install Xcode command line tools before building from source."
fi

echo
echo "Repository:"
info "$ROOT_DIR"

echo
echo "Build:"
if [[ -d "$ROOT_DIR/.build/ClipboardStation.app" ]]; then
  ok "packaged app exists: $ROOT_DIR/.build/ClipboardStation.app"
else
  warn "packaged app missing. Run ./Scripts/package-app.sh if you want a local .app bundle."
fi

echo
echo "Install:"
if [[ -d "$INSTALLED_APP" ]]; then
  ok "installed app exists: $INSTALLED_APP"
else
  warn "installed app missing. Run ./Scripts/install-local.sh."
fi

echo
echo "Launch agent:"
if [[ -f "$LAUNCH_AGENT" ]]; then
  ok "exists: $LAUNCH_AGENT"
  AGENT_TARGET="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$LAUNCH_AGENT" 2>/dev/null || true)"
  if [[ -n "$AGENT_TARGET" ]]; then
    info "target: $AGENT_TARGET"
    if [[ -x "$AGENT_TARGET" ]]; then
      ok "target executable exists"
    else
      warn "target executable is missing. Run ./Scripts/install-local.sh."
    fi
  else
    warn "could not read launch agent target. Reinstall with ./Scripts/install-local.sh."
  fi
  if launchctl print "gui/$(id -u)/com.local.clipboard-station.agent" >/dev/null 2>&1; then
    ok "loaded in launchctl"
  else
    warn "not loaded in launchctl. Run ./Scripts/install-local.sh."
  fi
else
  warn "missing. Run ./Scripts/install-local.sh."
fi

echo
echo "Process:"
if pgrep -fl "ClipboardStation" >/dev/null 2>&1; then
  ok "running process found"
  pgrep -fl "ClipboardStation" | sed 's/^/  INFO /'
else
  warn "not running. Open $INSTALLED_APP or run ./Scripts/install-local.sh."
fi

echo
echo "Local data:"
if [[ -d "$APP_SUPPORT" ]]; then
  ok "exists: $APP_SUPPORT"
  if [[ -f "$APP_SUPPORT/state.enc" ]]; then
    ok "encrypted snippet state exists"
  else
    info "encrypted snippet state has not been created yet"
  fi
  if [[ -d "$APP_SUPPORT/Attachments" ]]; then
    info "attachments folder exists"
  fi
else
  info "not created yet"
fi

echo
echo "Summary:"
if [[ "$WARNINGS" -eq 0 ]]; then
  echo "  OK   No install problems detected."
else
  echo "  WARN $WARNINGS potential issue(s) detected."
fi

echo
echo "Next steps:"
echo "  - If the floating bubble is missing, run ./Scripts/install-local.sh."
echo "  - If paste automation fails, grant Accessibility permission to ClipboardStation in macOS Settings."
echo "  - If macOS blocks the app, approve it in System Settings > Privacy & Security."
echo "  - If reports are needed, paste this doctor output into a GitHub issue after checking it contains no private paths you want to hide."
