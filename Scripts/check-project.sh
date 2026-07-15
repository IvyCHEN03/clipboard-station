#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "== Swift build =="
swift build

echo
echo "== Swift tests =="
swift test

echo
echo "== Shell syntax =="
for script in Scripts/*.sh; do
  bash -n "$script"
  echo "ok: $script"
done

echo
echo "== Script permissions =="
for script in Scripts/*.sh; do
  if [[ ! -x "$script" ]]; then
    echo "$script is not executable" >&2
    exit 1
  fi
  echo "ok: $script"
done

echo
echo "== Script dry-runs =="
./Scripts/sync-labels.sh >/dev/null
echo "ok: Scripts/sync-labels.sh"
./Scripts/make-release-notes.sh "$(tr -d '[:space:]' < VERSION)" >/dev/null
echo "ok: Scripts/make-release-notes.sh"

echo
echo "== Markdown links =="
./Scripts/check-doc-links.sh

echo
echo "== Secret scan =="
./Scripts/check-secrets.sh

echo
echo "== Browser extension =="
python3 -c 'import json; json.load(open("browser-extension/image-collector/manifest.json")); print("ok: browser-extension/image-collector/manifest.json")'
node --check browser-extension/image-collector/background.js
echo "ok: browser-extension/image-collector/background.js"
node --check browser-extension/image-collector/content.js
echo "ok: browser-extension/image-collector/content.js"
node --check browser-extension/image-collector/offscreen.js
echo "ok: browser-extension/image-collector/offscreen.js"

echo
echo "== Bundle plist =="
plutil -lint BundleResources/Info.plist

echo
echo "== Version metadata =="
version_file="$(tr -d '[:space:]' < VERSION)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' BundleResources/Info.plist)"
if [[ "$version_file" != "$plist_version" ]]; then
  echo "VERSION ($version_file) does not match Info.plist ($plist_version)" >&2
  exit 1
fi
echo "ok: $version_file"

echo
echo "Project checks passed."
