#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
elif [[ "$#" -gt 0 ]]; then
  echo "Usage: ./Scripts/push-current-branch.sh [--apply]" >&2
  exit 1
fi

BRANCH="$(git branch --show-current)"
if [[ -z "$BRANCH" ]]; then
  echo "Detached HEAD is not supported. Check out a branch first." >&2
  exit 1
fi

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
REMOTE="origin"
TARGET_BRANCH="$BRANCH"
if [[ -n "$UPSTREAM" ]]; then
  REMOTE="${UPSTREAM%%/*}"
  TARGET_BRANCH="${UPSTREAM#*/}"
fi

echo "Linggan GitHub sync"
echo "Repository: $ROOT_DIR"
echo "Local branch: $BRANCH"
echo "Remote target: $REMOTE/$TARGET_BRANCH"
echo

if [[ "$APPLY" -ne 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree has uncommitted files:"
    git status --short
    echo
  fi
  cat <<PLAN
Dry run only. No network changes were made.

Before uploading:
  1. Review and commit intentional changes.
  2. Run ./Scripts/check-project.sh
  3. Authenticate with gh auth login -h github.com -p https -w

Upload this branch with:
  ./Scripts/push-current-branch.sh --apply
PLAN
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Note: uncommitted files will remain local and will not be uploaded:"
  git status --short
  echo
fi

./Scripts/check-secrets.sh

if command -v gh >/dev/null 2>&1; then
  gh auth status -h github.com || {
    echo "GitHub CLI is not authenticated." >&2
    echo "Run: gh auth login -h github.com -p https -w" >&2
    echo "Then: gh auth setup-git" >&2
    exit 1
  }
fi

if [[ -n "$UPSTREAM" ]]; then
  git push "$REMOTE" "HEAD:$TARGET_BRANCH"
else
  git push --set-upstream "$REMOTE" "$BRANCH"
fi

echo
echo "Uploaded $(git rev-parse --short HEAD) to $REMOTE/$TARGET_BRANCH"
