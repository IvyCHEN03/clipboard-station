#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/ClipboardStation"
EXTENSION_DIR="$APP_SUPPORT/BrowserExtension"
SOURCE_EXTENSION_MANIFEST="$ROOT_DIR/browser-extension/image-collector/manifest.json"
INSTALLED_EXTENSION_MANIFEST="$EXTENSION_DIR/manifest.json"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.local.clipboard-station.agent.plist"
INSTALL_DIR="${LINGGAN_INSTALL_DIR:-$ROOT_DIR}"
INSTALLED_APP="$INSTALL_DIR/ClipboardStation.app"
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
  info "not installed. Enable 开机启动 in the app when you want login launch."
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
echo "Browser extension:"
info "Chrome should load unpacked from: $EXTENSION_DIR"
if [[ -f "$INSTALLED_EXTENSION_MANIFEST" ]]; then
  INSTALLED_EXTENSION_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$INSTALLED_EXTENSION_MANIFEST" 2>/dev/null || true)"
  if [[ -n "$INSTALLED_EXTENSION_VERSION" ]]; then
    ok "stable extension copy exists (version $INSTALLED_EXTENSION_VERSION)"
  else
    warn "stable extension manifest is unreadable. Run ./Scripts/install-browser-extension.sh."
  fi

  if [[ -f "$SOURCE_EXTENSION_MANIFEST" ]]; then
    SOURCE_EXTENSION_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$SOURCE_EXTENSION_MANIFEST" 2>/dev/null || true)"
    if [[ -n "$SOURCE_EXTENSION_VERSION" && "$INSTALLED_EXTENSION_VERSION" == "$SOURCE_EXTENSION_VERSION" ]]; then
      ok "installed extension matches the source version"
    elif [[ -n "$SOURCE_EXTENSION_VERSION" ]]; then
      warn "installed extension is version ${INSTALLED_EXTENSION_VERSION:-unknown}; source is $SOURCE_EXTENSION_VERSION. Run ./Scripts/install-browser-extension.sh."
    fi
  fi
else
  warn "stable extension copy is missing. Run ./Scripts/install-browser-extension.sh."
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
echo "  - If Chrome cannot update the extension, remove the old unpacked card once and load $EXTENSION_DIR."
echo "  - If paste automation fails, grant Accessibility permission to ClipboardStation in macOS Settings."
echo "  - If macOS blocks the app, approve it in System Settings > Privacy & Security."
echo "  - If reports are needed, paste this doctor output into a GitHub issue after checking it contains no private paths you want to hide."
