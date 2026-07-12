# Issue Triage Playbook

Use this playbook to keep feedback useful, private, and actionable.

## First Response

For every new issue:

1. Thank the reporter.
2. Check whether private clipboard content, API keys, screenshots, or logs need redaction.
3. Ask for copied diagnostics if missing.
4. Confirm the area: install, permissions, capture, screenshots/OCR, tables, AI tags, composer, release packaging, or docs.
5. Decide whether the issue needs a code fix, documentation update, FAQ update, or roadmap note.

## Priority

| Priority | Meaning | Examples |
| --- | --- | --- |
| P0 | Privacy, data loss, or app cannot launch | leaked secret in diagnostics, encrypted state corruption, launch crash |
| P1 | Core workflow broken | cannot collect text, cannot open floating bubble, composer output wrong |
| P2 | Important but workaround exists | AI provider error copy unclear, install warning confusing, OCR misses text |
| P3 | Polish or docs | README wording, screenshot request, small visual alignment |

## Labels

Recommended labels:

- `bug`
- `enhancement`
- `documentation`
- `question`
- `privacy`
- `permissions`
- `install`
- `ai-tags`
- `composer`
- `good first issue`
- `maintenance`

## Common Responses

### Missing Floating Bubble

Ask for:

- macOS version
- install method
- output from `./Scripts/doctor.sh`
- copied diagnostics from Settings

Point to [INSTALL.md](INSTALL.md) and [FAQ.md](FAQ.md).

### Automatic Paste Fails

Ask whether Accessibility permission is granted. If not, point to [INSTALL.md](INSTALL.md). If yes, ask for the target app and whether manual copy works.

### AI Tagging Fails

Ask for provider host, model name, HTTP status, and whether quota/billing is active. Do not ask for API keys. If the error repeats, add a troubleshooting note to [FAQ.md](FAQ.md).

### Install Or Release Problems

Ask whether the `.sha256` check passes. If macOS blocks the unsigned app, point to [INSTALL.md](INSTALL.md) and keep the signed-release roadmap visible.

## Documentation Feedback Loop

Update docs when:

- Two users ask the same setup question.
- A workaround is useful but buried in an issue.
- A permission problem depends on macOS behavior.
- A feature request reveals unclear positioning.
- A bug report needs the same diagnostics every time.

Docs to update:

- [FAQ.md](FAQ.md) for repeated questions.
- [INSTALL.md](INSTALL.md) for setup and permission steps.
- [GETTING_STARTED.md](GETTING_STARTED.md) for first-run confusion.
- [POSITIONING.md](POSITIONING.md) for product-scope confusion.
- [ROADMAP.md](../ROADMAP.md) for accepted future work.

## Closing Issues

Close an issue when:

- The fix is merged and released or clearly available from source.
- The report is a duplicate and links to the canonical issue.
- The feature is a documented non-goal.
- The reporter cannot provide enough detail after a reasonable follow-up.

When closing, leave a short note describing where the answer now lives: code, release, FAQ, install guide, or roadmap.
