# Contributing

Thanks for considering a contribution.

Linggan Floating Ball is an early macOS utility. Contributions are most useful when they keep the app local-first, simple, and reliable.

Please also follow the [Code of Conduct](CODE_OF_CONDUCT.md), especially when discussing clipboard contents, screenshots, API keys, logs, or other private material.

## Development Setup

Requirements:

- macOS 13+
- Xcode command line tools
- Swift 6 compatible toolchain

Run locally:

```bash
swift run
```

Package locally:

```bash
./Scripts/package-app.sh
open .build/ClipboardStation.app
```

Run checks:

```bash
./Scripts/check-project.sh
```

For documentation-only changes, `./Scripts/check-doc-links.sh` is a faster local check for broken Markdown links.

Before changing capture, persistence, AI tagging, or permissions, read [Architecture](docs/ARCHITECTURE.md).

## Product Principles

- Local-first by default.
- Clipboard content must not leave the device unless the user explicitly enables AI features.
- Prefer visible status over silent failure, especially for permissions and shortcuts.
- Keep the floating bubble and menu bar icon as reliable entry points.
- Avoid adding cloud services, telemetry, or accounts.

## Good First Issues

See [Good First Issues](docs/GOOD_FIRST_ISSUES.md) for scoped starter tasks across documentation, tests, macOS reliability, demo assets, and product polish.

## Pull Request Checklist

- Explain the user-facing problem.
- Keep changes scoped.
- Avoid committing build artifacts from `.build/`.
- Do not include API keys, local data, screenshots with private content, or Keychain material.
- Run `swift build`.
- Run `swift test`.
- Run `./Scripts/check-doc-links.sh` for documentation changes.
- If UI behavior changes, include before/after screenshots when possible.
- Update `CHANGELOG.md` for user-facing, documentation, release, or maintenance changes.
- Choose labels from [GitHub Labels](docs/LABELS.md) when the change should appear in generated release notes.

Code ownership is tracked in [.github/CODEOWNERS](.github/CODEOWNERS).
GitHub Actions dependency updates are managed by [.github/dependabot.yml](.github/dependabot.yml).
Issue response and prioritization guidance lives in [Triage Playbook](docs/TRIAGE.md).

## Security and Privacy

Do not open public issues with private clipboard contents, API keys, or local encrypted data. If you find a privacy-sensitive bug, describe the behavior without including the sensitive payload.
