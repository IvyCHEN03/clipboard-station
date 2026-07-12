# User Guide

Linggan Floating Ball is built for one daily workflow: collect useful fragments while working across many AI chats, then assemble them into a cleaner prompt or answer.

For a quick visual walkthrough plan, see [DEMO.md](DEMO.md).

## First Run

1. Install the app:

```bash
./Scripts/install-local.sh
```

2. Look for the small blue bubble near the screen edge.
3. Click the bubble or the menu bar icon to open the station.
4. Click `载入示例` if you want to try the workflow without using private clipboard content.
5. Copy text, a screenshot, or spreadsheet cells from any app.
6. Confirm the snippet appears in the station.

If the bubble does not appear, run:

```bash
./Scripts/doctor.sh
```

## Collect Snippets

- Text: use normal `Cmd+C`.
- Screenshot: copy or import the screenshot; image snippets stay visible in the list.
- Spreadsheet cells: copied tabular text is stored as a table-like snippet.
- Manual import: click the `+` button in the composition box to import the current clipboard.

The app intentionally allows repeated captures. If you copy the same content three times, it can become three separate snippets.

## Find Snippets

- Use search for title, body, source, or tag.
- Use time filters: Today, 3 days, or Fish 7-day memory.
- Select one or more tag chips to narrow the list.
- Click a selected tag again to remove it from the filter.

The header shows the current filtered count so hidden snippets are not mistaken for lost snippets.

## Compose With Blocks

1. Drag snippets into the bottom composition box.
2. Reorder blocks with drag, up/down controls, or numeric positions.
3. Click between blocks to add custom text.
4. Copy the composed result.

When copying composed text:

- Text snippets output their text.
- Table snippets output their tabular text.
- Screenshot snippets output OCR text when OCR exists; otherwise they are skipped in text output but remain draggable as images.

## AI Tags

AI tagging is optional and off by default.

1. Open Settings.
2. Enable AI title and tag generation.
3. Fill an OpenAI-compatible Base URL, model name, and API key.
4. Click `Tag` to generate tags for snippets that do not already have tags.

Existing tags are preserved. Failed snippets show a failure state and can be retried individually.

## Privacy

- Clipboard data is stored locally.
- Persistent data is encrypted with a Keychain-backed key.
- Nothing is uploaded unless AI tagging is enabled and configured.
- API keys are stored in macOS Keychain.

## Common Fixes

- Bubble missing: run `./Scripts/install-local.sh`, then `./Scripts/doctor.sh`.
- Paste automation fails: grant Accessibility permission in macOS Settings.
- AI returns quota errors: check provider billing and quota.
- Old app icon still appears: relaunch the app; Finder or Dock icon caches may update after a short delay.

When opening a GitHub issue, open Settings and click `复制诊断信息`. The copied text includes non-sensitive app status such as version, macOS, permissions, settings toggles, and snippet counts.
