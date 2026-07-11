# Contributing

Thanks for considering a contribution.

Linggan Floating Ball is an early macOS utility. Contributions are most useful when they keep the app local-first, simple, and reliable.

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

## Product Principles

- Local-first by default.
- Clipboard content must not leave the device unless the user explicitly enables AI features.
- Prefer visible status over silent failure, especially for permissions and shortcuts.
- Keep the floating bubble and menu bar icon as reliable entry points.
- Avoid adding cloud services, telemetry, or accounts.

## Good First Issues

- Improve onboarding and permission copy.
- Add screenshots or a demo GIF.
- Add tests for `AIEnricher` parsing behavior.
- Add tests for persistence and import type detection.
- Improve accessibility labels and keyboard navigation.
- Improve README installation steps for non-developers.

## Pull Request Checklist

- Explain the user-facing problem.
- Keep changes scoped.
- Avoid committing build artifacts from `.build/`.
- Do not include API keys, local data, screenshots with private content, or Keychain material.
- Run `swift build`.
- If UI behavior changes, include before/after screenshots when possible.

## Security and Privacy

Do not open public issues with private clipboard contents, API keys, or local encrypted data. If you find a privacy-sensitive bug, describe the behavior without including the sensitive payload.
