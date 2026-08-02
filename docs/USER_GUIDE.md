# User Guide

Linggan Floating Ball is built for one daily workflow: collect useful fragments while working across many AI chats, then assemble them into a cleaner prompt or answer.

For a quick visual walkthrough plan, see [DEMO.md](DEMO.md).

For common privacy, shortcut, install, and AI questions, see [FAQ.md](FAQ.md).

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

Use the `?` button in the header or the Help section in Settings to open the GitHub getting-started guide, FAQ, or issue form.

If the bubble does not appear, run:

```bash
./Scripts/doctor.sh
```

## Collect Snippets

- Text: use normal `Cmd+C`.
- Screenshot: copy or import the screenshot; image snippets stay visible in the list.
- Spreadsheet cells: tab-delimited copied cells from Excel, Numbers, or Google Sheets are stored as table-like snippets.
- Manual import: use `导入当前剪贴板` in the empty state, or enable clipboard
  monitoring for ongoing capture.

The app intentionally allows repeated captures. If you copy the same content three times, it can become three separate snippets.

## Find Snippets

- Use search for title, body, source, or tag.
- Use time filters: Today, 3 days, or Fish 7-day memory.
- Click the star on a snippet to favorite it, then use the `收藏` filter to show favorites only. Favorites do not expire into the memory shore automatically.
- Click `日期` to choose an inclusive start and end date. Applying a custom range clears the preset time filter, while search and tag filters continue to apply.
- Select one or more tag chips to narrow the list.
- Click a selected tag again to remove it from the filter.

The header shows the current filtered count so hidden snippets are not mistaken for lost snippets.

If copied text contains a recognizable date and time, the snippet shows Calendar and Reminder actions. They create a local event or reminder only after you click the corresponding action.

## Compose With Blocks

1. Drag one snippet, or select several snippets and drag the selection, into
   the bottom composition box.
2. Reorder blocks with drag, up/down controls, or numeric positions.
3. Click between blocks to add custom text.
4. Use the pencil icon to add an optional instruction.
5. Copy the composed result.

Selected snippets are added in their current visible order. Snippets already in
the composer are skipped, and screenshots without OCR stay available as
draggable images without producing an empty text block.

When copying composed text:

- Text snippets output their text.
- Table snippets output their tabular text.
- Screenshot snippets output OCR text when OCR exists; otherwise they are skipped in text output but remain draggable as images.

## Tags

AI tagging is optional and off by default.

1. Open Settings.
2. Enable AI title and tag generation.
3. Fill an OpenAI-compatible Base URL, model name, and API key.
4. Click `Tag` to generate tags for snippets that do not already have tags.

Existing tags are preserved. Failed snippets show a failure state and can be retried individually.

Use the outlined plus beside the category row or a snippet to create and manage
your own tags. Custom tags and AI tags are stored separately, but search,
filtering, statistics, Markdown export, and backups use their merged display.
Custom tags have an outlined style so their origin remains visible.

## AI Composer

After arranging blocks and bridge text, use the wand menu to choose:

- Faithful merge: connect the blocks without inventing new claims.
- Summarize: condense the source material.
- Compare: organize similarities, differences, and open questions.
- Generate prompt: turn the material into a reusable prompt.

The model receives the optional instruction and a bounded context package. Each
source includes its title, source type, tags, and exportable body under an
explicit `[片段 N]` boundary. The original snippets and block order remain
unchanged. Editing a source, its tags, block order, bridge text, instruction, or
AI mode invalidates the previous result.

The copy menu can output a clean body, a body with numbered sources, the full
context package, or paste the clean body into the active app.

## Privacy

- Clipboard data is stored locally.
- Persistent data is encrypted with a Keychain-backed key.
- Nothing is uploaded by default. Snippet text is sent only when AI tagging
  runs or when you explicitly run an AI composer action.
- API keys are stored in macOS Keychain.

## Local Backup

Open Settings and use `导出 JSON 备份` to save a local backup containing snippets, settings, and attachment data such as screenshots or table files. Use `导入 JSON 备份` to restore it later.

Linggan also keeps the previous valid encrypted state as
`state.backup.enc`. If the primary encrypted state cannot be decoded, the app
automatically falls back to that backup.

Items removed manually or moved by the seven-day memory rule wait in
`回忆浅滩`. Use `全部找回` to return every item to the main list. Recovered
items are automatically favorited so they do not immediately expire again.

Backup files are not encrypted by the app. Store them somewhere private if they contain sensitive clipboard content. API keys are not included in backups.

Use `导出当前筛选为 Markdown` when you want a readable text handoff for notes, issues, or another AI chat. It exports the current filtered snippet list, including titles, metadata, tags, text, table text, and screenshot OCR when available.

Use `清除本地片段和附件` in Settings when you want to remove snippets, composer text, and local attachment files from this Mac. Exported backup files and Keychain API keys are not removed.

## Common Fixes

- Bubble missing: run `./Scripts/install-local.sh`, then `./Scripts/doctor.sh`.
- Paste automation fails: grant Accessibility permission in macOS Settings.
- AI returns quota errors: check provider billing and quota.
- Old app icon still appears: relaunch the app; Finder or Dock icon caches may update after a short delay.

When opening a GitHub issue, open Settings and click `复制诊断信息`. The copied text includes non-sensitive app status such as version, macOS, permissions, settings toggles, and snippet counts.
