# Privacy

Linggan Floating Ball is designed as a local-first clipboard utility.

## What Is Stored Locally

The app may store:

- Text snippets copied or imported by the user.
- OCR text recognized from screenshots.
- Metadata such as title, tags, source type, creation time, and ordering.
- Attachment files such as screenshot PNGs or copied spreadsheet files.
- App settings, including whether clipboard monitoring and AI features are enabled.

Snippet state is saved at:

```text
~/Library/Application Support/ClipboardStation/state.enc
```

Attachments are saved under:

```text
~/Library/Application Support/ClipboardStation/Attachments/
```

The encryption key is stored in macOS Keychain.

## What Leaves the Device

By default, nothing is uploaded.

Content may leave the device only when:

- The user provides an AI API base URL, model, and API key.
- The user runs AI title/tag generation, which sends only snippets that need tags.
- The user clicks `Polish`, which sends only the current composer text.

API keys are stored in macOS Keychain and are not committed to the repository.

## Local Backups

If the user exports a JSON backup, the backup file contains snippets, settings, and attachment data such as screenshots or table files. The backup is written only to the location selected by the user.

Backup files are not encrypted by the app. Treat them like private clipboard data and store or delete them carefully. API keys are not exported.

## Clipboard Monitoring

When clipboard monitoring is enabled, the app polls the macOS pasteboard change count and imports supported content types. The current implementation focuses on:

- Plain text
- Spreadsheet-like text
- Images/screenshots
- Supported file URLs

Internal writes made by the app are ignored where possible to avoid repeatedly importing the app's own copied content.

## Browser Page Archives

The optional browser extension can save the current page as a static HTML file and a full-page PNG screenshot. Both files may contain whatever is visible on that page, so review sensitive or account-only pages before archiving them.

Archives are written through the browser download manager under `Downloads/LingganPages/`. They are not uploaded by Linggan. The HTML snapshot removes scripts, Content Security Policy metadata, and form field values. Chrome's page debugger is attached only for the requested full-page screenshot and is detached as soon as capture finishes.

## Permissions

Accessibility permission is used to simulate copy/paste keyboard events. It does not grant the app permission to upload content.

The floating bubble and menu bar app are local UI surfaces. They do not create network traffic.

## Recommended User Practices

- Do not run AI tagging or `Polish` on sensitive content.
- Use a provider-specific API key with limited permissions.
- Remove old snippets from the station when they are no longer useful.
- Use Settings > `清除本地片段和附件` to remove saved snippets, composer text, and local attachments from this Mac.
- Delete `state.enc` and the `Attachments` folder if you want to clear local data outside the app.
