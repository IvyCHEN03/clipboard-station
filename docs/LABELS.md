# GitHub Labels

Use these labels to keep issues, pull requests, triage, and generated release notes consistent.

The source of truth for release grouping is [.github/release.yml](../.github/release.yml). The source of truth for issue response is [TRIAGE.md](TRIAGE.md).

## Recommended Labels

| Label | Color | Purpose |
| --- | --- | --- |
| `bug` | `d73a4a` | Broken behavior or confusing failures. |
| `enhancement` | `a2eeef` | User-facing improvements. |
| `documentation` | `0075ca` | Docs, demos, screenshots, and release copy. |
| `question` | `d876e3` | Usage questions and setup help. |
| `privacy` | `5319e7` | Local data, clipboard boundaries, AI upload behavior, and user trust. |
| `security` | `b60205` | Security-sensitive or private-data handling reports. |
| `permissions` | `fbca04` | Accessibility, launch agent, paste automation, and macOS permission behavior. |
| `install` | `c2e0c6` | Build, packaging, launch, repair, and uninstall flow. |
| `ai-tags` | `7057ff` | AI-generated titles, tags, provider settings, and quota errors. |
| `composer` | `bfd4f2` | Block composition, ordering, Markdown export, and prompt output. |
| `good first issue` | `7057ff` | Small scoped tasks for new contributors. |
| `maintenance` | `ededed` | Repository hygiene, CI, release process, scripts, and refactors. |
| `dependencies` | `0366d6` | Dependency and GitHub Actions updates. |
| `ignore-for-release` | `ffffff` | Changes that should not appear in generated release notes. |

## Create Or Update Labels

Preview commands:

```bash
./Scripts/sync-labels.sh
```

Apply with GitHub CLI:

```bash
./Scripts/sync-labels.sh --apply
```

The script uses `gh label create --force`, so it can create missing labels or update existing label color/description.

## Maintenance Rule

When adding a new label to an issue template, release category, PR checklist, or triage response, update:

- [LABELS.md](LABELS.md)
- [.github/release.yml](../.github/release.yml), if the label affects generated release notes
- [TRIAGE.md](TRIAGE.md), if maintainers should use it during issue response
