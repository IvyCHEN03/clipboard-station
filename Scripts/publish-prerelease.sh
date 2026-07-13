#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APPLY=0
RAW_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

usage() {
  cat <<USAGE
Usage: ./Scripts/publish-prerelease.sh [--apply] [vX.Y.Z]

Without --apply, prints the release plan only.
With --apply, runs local gates, pushes main, creates the tag, and pushes it.
USAGE
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    v*|[0-9]*)
      RAW_VERSION="$1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

VERSION="${RAW_VERSION#v}"
TAG="v$VERSION"
ZIP_PATH=".build/dist/Linggan-Floating-Ball-$TAG.zip"

echo "Linggan Floating Ball prerelease plan"
echo "Version: $VERSION"
echo "Tag: $TAG"
echo

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "This release script must run from main." >&2
  exit 1
fi

if [[ "$APPLY" -ne 1 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Warning: working tree is not clean. Commit or stash changes before using --apply."
    git status --short
    echo
  fi
  if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Warning: tag already exists locally: $TAG"
    echo
  fi
  cat <<PLAN
Dry run only. No network changes were made.

To publish after GitHub auth is ready:

  ./Scripts/publish-prerelease.sh --apply $TAG

The apply run will:

  1. Run ./Scripts/check-project.sh
  2. Generate release notes
  3. Generate the release zip and checksum
  4. Verify $ZIP_PATH
  5. Push main to origin
  6. Create local tag $TAG
  7. Push tag $TAG to origin

Before using --apply, revoke exposed tokens and authenticate GitHub safely.
See docs/PUBLISHING.md.
PLAN
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before publishing." >&2
  git status --short
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag already exists locally: $TAG" >&2
  exit 1
fi

echo "== GitHub auth hint =="
if command -v gh >/dev/null 2>&1; then
  gh auth status || {
    echo "GitHub CLI is not authenticated. Run gh auth login or configure git credentials." >&2
    exit 1
  }
else
  echo "GitHub CLI not found. Continuing with git credentials only."
fi

echo
echo "== Local gates =="
./Scripts/check-project.sh

echo
echo "== Release assets =="
./Scripts/make-release-notes.sh "$TAG"
./Scripts/make-release-zip.sh "$TAG"
./Scripts/verify-release.sh "$ZIP_PATH"

echo
echo "== Push main =="
git push origin main

echo
echo "== Create and push tag =="
git tag "$TAG"
git push origin "$TAG"

cat <<DONE

Prerelease tag pushed: $TAG

Next:
  - Wait for the GitHub release workflow.
  - Confirm the release is marked prerelease.
  - Download and verify the zip and checksum from GitHub.
  - Update repository profile and social preview.
DONE
