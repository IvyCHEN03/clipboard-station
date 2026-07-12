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
echo "== Markdown links =="
./Scripts/check-doc-links.sh

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
