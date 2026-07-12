#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

markdown_list="$(mktemp)"
trap 'rm -f "$markdown_list"' EXIT

find . \
  -path "./.build" -prune -o \
  -path "./.swiftpm" -prune -o \
  -name "*.md" -type f -print0 | sort -z > "$markdown_list"

if [[ ! -s "$markdown_list" ]]; then
  echo "No Markdown files found."
  exit 0
fi

failed=0

while IFS=$'\t' read -r file link; do
  [[ -n "$file" && -n "$link" ]] || continue

  case "$link" in
    http://*|https://*|mailto:*|"#"*|"")
      continue
      ;;
  esac

  target="${link%%#*}"
  target="${target%%\?*}"
  [[ -n "$target" ]] || continue

  if [[ "$target" == /* ]]; then
    resolved=".$target"
  else
    resolved="$(dirname "$file")/$target"
  fi

  if [[ ! -e "$resolved" ]]; then
    echo "Broken local Markdown link in ${file#./}: $link"
    failed=1
  fi
done < <(
  xargs -0 perl -Mopen=locale -ne 'while (/\[[^\]]*\]\(([^)]+)\)/g) { print "$ARGV\t$1\n" }' < "$markdown_list"
)

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "Markdown links ok."
