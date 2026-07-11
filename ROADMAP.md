# Roadmap

This roadmap is product-oriented rather than exhaustive. The goal is to make Linggan Floating Ball reliable enough for daily use and clear enough for new open-source users to understand in minutes.

## Now

- Make the floating bubble the primary entry point instead of relying on fragile global shortcuts.
- Keep all copied snippets local by default.
- Support text, screenshots, spreadsheet-like copied text, AI tags, search, sorting, and composition blocks.
- Keep the app source-first while the product stabilizes.

## Next

- Add signed and notarized builds for non-developer installation.
- Improve first-run onboarding with permission checks and a tiny guided workflow.
- Add a sample screenshot or short demo GIF to the README.
- Add import/export for local backup and migration.
- Add focused unit tests for persistence, AI response parsing, duplicate handling, and pasteboard import.
- Polish empty states, status messages, and error recovery.

## Later

- Optional updater for packaged releases.
- Better OCR controls for screenshots, including language selection and re-run OCR.
- Configurable capture rules per content type.
- More flexible block composer with keyboard-first editing.
- Optional local-only semantic tags when system frameworks make it practical.

## Non-Goals

- Cloud sync by default.
- Server-side clipboard storage.
- Background upload of clipboard content.
- Replacing a full clipboard manager.
- Becoming a general note-taking app.
