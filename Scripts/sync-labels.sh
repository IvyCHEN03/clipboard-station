#!/usr/bin/env bash
set -euo pipefail

APPLY="false"
if [[ "${1:-}" == "--apply" ]]; then
  APPLY="true"
fi

LABELS=(
  "bug|d73a4a|Broken behavior or confusing failures."
  "enhancement|a2eeef|User-facing improvements."
  "documentation|0075ca|Docs, demos, screenshots, and release copy."
  "question|d876e3|Usage questions and setup help."
  "privacy|5319e7|Local data, clipboard boundaries, AI upload behavior, and user trust."
  "security|b60205|Security-sensitive or private-data handling reports."
  "permissions|fbca04|Accessibility, launch agent, paste automation, and macOS permission behavior."
  "install|c2e0c6|Build, packaging, launch, repair, and uninstall flow."
  "ai-tags|7057ff|AI-generated titles, tags, provider settings, and quota errors."
  "composer|bfd4f2|Block composition, ordering, Markdown export, and prompt output."
  "good first issue|7057ff|Small scoped tasks for new contributors."
  "maintenance|ededed|Repository hygiene, CI, release process, scripts, and refactors."
  "dependencies|0366d6|Dependency and GitHub Actions updates."
  "ignore-for-release|ffffff|Changes that should not appear in generated release notes."
)

if [[ "$APPLY" == "true" ]] && ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI not found. Install gh or run without --apply to preview commands." >&2
  exit 1
fi

for entry in "${LABELS[@]}"; do
  IFS="|" read -r name color description <<< "$entry"
  cmd=(gh label create "$name" --color "$color" --description "$description" --force)
  if [[ "$APPLY" == "true" ]]; then
    "${cmd[@]}"
  else
    printf "%q " "${cmd[@]}"
    printf "\n"
  fi
done
