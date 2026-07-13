# Roadmap

This roadmap is product-oriented rather than exhaustive. The goal is to make Linggan Floating Ball reliable enough for daily use and clear enough for new open-source users to understand in minutes.

## Done In v0.4

- Make the floating bubble the primary entry point instead of relying on fragile global shortcuts.
- Keep all copied snippets local by default.
- Support text, screenshots, spreadsheet-like copied text, AI tags, search, sorting, and composition blocks.
- Add first-run onboarding, demo snippets, diagnostics, in-app help links, and user-facing guides.
- Add local JSON backup, Markdown export, and privacy-focused local data cleanup.
- Add tests for models, AI response parsing, demo content, diagnostics, backup export, Markdown export, and attachment cleanup.
- Add open-source launch docs, issue templates, PR checks, labels, release notes, release verification, and repository profile guidance.

## Next

- Add signed and notarized builds for non-developer installation.
- Add a sample screenshot or short demo GIF to the README.
- Add focused tests for persistence and pasteboard import edge cases.
- Polish empty states, status messages, and error recovery based on first external feedback.
- Improve keyboard-first navigation in the snippet list and block composer.

## Later

- Optional updater for packaged releases.
- Better OCR controls for screenshots, including language selection and re-run OCR.
- Configurable capture rules per content type.
- Optional local-only semantic tags when system frameworks make it practical.

## Non-Goals

- Cloud sync by default.
- Server-side clipboard storage.
- Background upload of clipboard content.
- Replacing a full clipboard manager.
- Becoming a general note-taking app.
