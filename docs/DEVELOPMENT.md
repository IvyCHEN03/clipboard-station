# Development Guide

This guide is for people making local changes before opening a pull request.

## Fast Path

```bash
git clone https://github.com/IvyCHEN03/clipboard-station.git
cd clipboard-station
swift build
swift test
./Scripts/check-project.sh
```

To install the app locally after changing code:

```bash
./Scripts/install-local.sh
```

The install script rebuilds the app, replaces `~/Applications/ClipboardStation.app`, and restarts the user LaunchAgent.

## Common Commands

| Task | Command |
| --- | --- |
| Run the app from source | `swift run` |
| Build debug target | `swift build` |
| Run tests | `swift test` |
| Package `.app` bundle | `./Scripts/package-app.sh` |
| Install local app and launch agent | `./Scripts/install-local.sh` |
| Remove local app and launch agent | `./Scripts/uninstall-local.sh` |
| Diagnose local install | `./Scripts/doctor.sh` |
| Check Markdown links | `./Scripts/check-doc-links.sh` |
| Scan tracked files for token-shaped secrets | `./Scripts/check-secrets.sh` |
| Run all local gates | `./Scripts/check-project.sh` |

## Where To Start

Small, high-value areas:

- Documentation: install friction, FAQ, demo instructions, release notes.
- Tests: pasteboard classification, AI response parsing, filtering, backup, exports.
- Reliability: launch-at-login status, Accessibility messaging, floating bubble behavior.
- Accessibility: labels, keyboard navigation, clearer status text.
- Demo assets: redacted screenshots and a short GIF using demo snippets.

Read [GOOD_FIRST_ISSUES.md](GOOD_FIRST_ISSUES.md) for starter tasks.

## Code Map

- `Sources/ClipboardStation/StationView.swift`: main SwiftUI station window.
- `Sources/ClipboardStation/SnippetStore.swift`: capture, snippet state, filtering, composer, AI queue orchestration.
- `Sources/ClipboardStation/ClipboardMonitor.swift`: pasteboard polling.
- `Sources/ClipboardStation/PasteboardContentClassifier.swift`: text/table classification.
- `Sources/ClipboardStation/AIEnricher.swift`: OpenAI-compatible title/tag generation.
- `Sources/ClipboardStation/PersistentStore.swift`: encrypted local state.
- `Sources/ClipboardStation/KeychainCrypto.swift`: Keychain-backed encryption key.
- `Sources/ClipboardStation/FloatingTriggerController.swift`: small desktop floating bubble.
- `Sources/ClipboardStation/StatusBarController.swift`: menu bar app lifecycle.
- `Tests/ClipboardStationTests/`: XCTest coverage for model, AI parsing, backup, exports, diagnostics, cleanup, and pasteboard classification.

For architecture details, read [ARCHITECTURE.md](ARCHITECTURE.md).

## Privacy Rules

Do not commit:

- Real clipboard contents.
- API keys, personal access tokens, or provider secrets.
- Screenshots with private messages, names, local file paths, account pages, or billing screens.
- Local encrypted state from `~/Library/Application Support/ClipboardStation`.
- Build artifacts from `.build/`.

Use demo snippets, synthetic text, or redacted screenshots. Before opening a PR, run:

```bash
./Scripts/check-secrets.sh
```

The scanner catches common token shapes, but it cannot judge whether a screenshot or copied text is private. Review assets manually.

## Testing Expectations

Use the narrowest useful check while developing:

- Documentation-only change: `./Scripts/check-doc-links.sh`
- Script change: `bash -n Scripts/<script>.sh`
- Swift model or parser change: `swift test`
- Release, install, privacy, or workflow change: `./Scripts/check-project.sh`

Before a pull request, run:

```bash
./Scripts/check-project.sh
```

## Pull Request Shape

A good PR:

- Names the user problem.
- Keeps the change scoped.
- Includes before/after screenshots for UI changes when useful.
- Updates docs when behavior changes.
- Updates `CHANGELOG.md` for user-facing, docs, release, or maintenance changes.
- Avoids broad refactors unless they directly reduce risk or unblock a clear feature.

If the PR touches capture, persistence, AI tagging, attachments, permissions, or diagnostics, mention the privacy impact explicitly.
