#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
DIST_DIR="$ROOT_DIR/.build/dist"
OUTPUT="$DIST_DIR/RELEASE_NOTES-v$VERSION.md"

mkdir -p "$DIST_DIR"

awk '
  /^## Unreleased$/ { in_section=1; next }
  /^## / && in_section { exit }
  in_section && NF { print }
' "$ROOT_DIR/CHANGELOG.md" > "$OUTPUT.tmp"

if [[ ! -s "$OUTPUT.tmp" ]]; then
  echo "No Unreleased changelog entries found." >&2
  rm -f "$OUTPUT.tmp"
  exit 1
fi

cat > "$OUTPUT" <<NOTES
# Linggan Floating Ball v$VERSION

Linggan Floating Ball is a local-first macOS clipboard station for collecting text, screenshots, and table snippets while working across multiple AI chats.

## Who Should Install This

- People who are comfortable running an unsigned macOS app.
- People who want a local clipboard station for AI prompt composition.
- People who understand that optional AI tagging sends selected snippet text to their configured provider.

## Highlights

$(cat "$OUTPUT.tmp")

## Download

Download:

- \`Linggan-Floating-Ball-v$VERSION.zip\`
- \`Linggan-Floating-Ball-v$VERSION.zip.sha256\`

Verify the checksum:

\`\`\`bash
shasum -a 256 -c Linggan-Floating-Ball-v$VERSION.zip.sha256
\`\`\`

Then unzip and open \`ClipboardStation.app\`.

## Important Install Note

This release is currently unsigned and not notarized. macOS may block the first launch. If that happens, open System Settings > Privacy & Security and allow the app manually.

For full install and uninstall steps, read \`docs/INSTALL.md\`.

## Privacy Notes

- Clipboard content stays local by default.
- Snippets are stored locally with Keychain-backed encryption.
- AI tagging is off by default.
- If AI tagging is enabled, snippet text is sent only to the configured OpenAI-compatible endpoint.
- API keys are stored in macOS Keychain.

Read \`PRIVACY.md\` before using AI tagging with sensitive content.

## Known Limitations

- The app is not signed or notarized yet.
- Global shortcuts can conflict with other apps; the floating bubble is the recommended entry point.
- OCR quality depends on the copied screenshot.

## Feedback

Please use the GitHub issue templates:

- Bug report for broken behavior.
- Usage question for setup or workflow questions.
- Feature request for product ideas.

Do not paste private clipboard contents, API keys, or sensitive screenshots into public issues.
NOTES

rm -f "$OUTPUT.tmp"
echo "$OUTPUT"
