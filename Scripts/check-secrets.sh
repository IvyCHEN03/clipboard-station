#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Secret scan requires a git checkout." >&2
  exit 1
fi

patterns=(
  'github_pat_[A-Za-z0-9_]{20,}'
  'gh[pousr]_[A-Za-z0-9_]{20,}'
  'sk-[A-Za-z0-9_-]{20,}'
  'xox[baprs]-[A-Za-z0-9-]{20,}'
  'AKIA[0-9A-Z]{16}'
)

tracked_files="$(mktemp)"
matches="$(mktemp)"
trap 'rm -f "$tracked_files" "$matches"' EXIT

git ls-files -z > "$tracked_files"

if [[ ! -s "$tracked_files" ]]; then
  echo "No tracked files to scan."
  exit 0
fi

failed=0
for pattern in "${patterns[@]}"; do
  if xargs -0 grep -nE "$pattern" < "$tracked_files" >> "$matches"; then
    failed=1
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "Potential secret found in tracked files:" >&2
  sed 's/^/  /' "$matches" >&2
  echo >&2
  echo "Remove the secret, rotate it with the provider, and commit only redacted examples." >&2
  exit 1
fi

echo "Secret scan ok."
