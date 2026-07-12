# Good First Issues

This project is early and especially benefits from small, focused improvements. Good first issues should make the app easier to trust, install, understand, test, or demo.

## Documentation

- Add screenshots following [DEMO.md](DEMO.md).
- Improve the [Install Guide](INSTALL.md) for non-developers.
- Add troubleshooting notes for a specific macOS version.
- Translate the README summary into clearer Chinese or English copy.
- Improve the FAQ when a question repeats in issues.

## Tests

- Add tests for import type detection.
- Add tests for persistence behavior when saving is disabled.
- Add tests for AI error parsing and user-facing messages.
- Add tests for composer text ordering.
- Add tests for repeated-copy behavior.

## macOS Reliability

- Reproduce and document permission edge cases.
- Improve launch-at-login status reporting.
- Improve Accessibility warning copy.
- Improve behavior when another app owns a global shortcut.
- Verify floating bubble behavior across multiple displays.

## Demo Assets

- Record a short README hero GIF.
- Create redacted screenshots for the empty state, snippet list, filters, composer, and settings.
- Add a small sample workflow using demo snippets.
- Improve release-note copy for non-technical users.

## Product Polish

- Improve VoiceOver labels and keyboard navigation.
- Reduce visual clutter in Settings.
- Make empty states clearer without adding long instructions.
- Improve status messages for AI provider quota failures.
- Add small affordances that make local-first privacy more obvious.

## Before You Start

1. Read [CONTRIBUTING.md](../CONTRIBUTING.md).
2. Read [ARCHITECTURE.md](ARCHITECTURE.md) if touching code.
3. Run:

```bash
./Scripts/check-project.sh
```

Keep pull requests small. A focused fix with a clear before/after is more useful than a broad refactor.
