# Architecture

Linggan Floating Ball is a small native macOS app. The product goal is to keep clipboard-heavy AI work fast, local, and understandable.

## Runtime Surfaces

- `main.swift`: creates the menu bar app and installs the app delegate.
- `StatusBarController.swift`: owns the menu bar icon, the station window, the floating trigger, and lifecycle wiring.
- `FloatingTriggerController.swift`: shows the small draggable blue bubble used as the most reliable app entry point.
- `StationView.swift`: SwiftUI station UI for snippets, filters, settings, multi-select, and the composition box.

## Capture Pipeline

1. `ClipboardMonitor.swift` polls `NSPasteboard.general.changeCount`.
2. `ScreenshotShortcutMonitor.swift` watches screenshot-related pasteboard changes.
3. `HotKeyController.swift` and `KeyboardShortcutMonitor.swift` provide best-effort shortcut entry points.
4. `SnippetStore.swift` normalizes pasteboard content into `Snippet` models.
5. `StationView.swift` renders snippets and lets users copy, paste, drag, sort, tag, and compose them.

The app intentionally allows repeated captures. Re-copying the same content can create multiple independent snippets.

## Data Model

- `Snippet`: one captured item. It can be text, screenshot, spreadsheet-like text, or file-backed content.
- `SnippetSource`: where the item came from, such as clipboard listening, manual import, hotkey selection, or screenshot capture.
- `SnippetKind`: display and export behavior for text, screenshot, spreadsheet, or file snippets.
- `StationSettings`: user preferences, AI provider configuration, launch behavior, and persistence settings.
- `TimeFilter`: the user-facing date filters used by the station.

## Persistence And Privacy

- `PersistentStore.swift` serializes `PersistedState`.
- `KeychainCrypto.swift` encrypts the serialized state before writing it to disk.
- `KeychainCredentials.swift` stores AI API credentials in macOS Keychain.
- Snippet state is stored under `~/Library/Application Support/ClipboardStation/state.enc`.
- Attachments are stored under `~/Library/Application Support/ClipboardStation/Attachments`.

No clipboard content is uploaded by default. Network requests happen only when AI tagging is enabled and configured.

## AI Tagging

- `AIEnricher.swift` calls an OpenAI-compatible chat completions endpoint.
- `SnippetStore.enrichAllMissingTags()` queues snippets that have no tags and exportable text.
- Existing tags are preserved.
- Failures are stored on the snippet so the UI can show retry affordances.

## Permissions

- Accessibility is required for simulated copy/paste actions.
- Launch-at-login is managed by `LaunchAtLogin.swift` and the local install script.
- The app can still collect manually imported content without full automation permissions.

## Tests

Current tests focus on stable core behavior:

- AI enrichment JSON parsing.
- Snippet search and tag matching.
- Time filter boundaries.
- Legacy snippet decoding defaults.

Run them with:

```bash
swift test
```

## Contribution Guidelines

When changing capture, persistence, or AI behavior:

- Keep the local-first privacy model intact.
- Add or update tests for model-level behavior.
- Update `PRIVACY.md` if data flow changes.
- Update `docs/USER_GUIDE.md` if the user workflow changes.
