# Privacy

Linggan Floating Ball is designed as a local-first clipboard utility.

## What Is Stored Locally

The app may store:

- Text snippets copied or imported by the user.
- OCR text recognized from screenshots.
- Metadata such as title, tags, source type, creation time, and ordering.
- Attachment files such as screenshot PNGs or copied spreadsheet files.
- App settings, including whether clipboard monitoring and AI tagging are enabled.

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

- The user enables AI title/tag generation.
- The user provides an AI API base URL, model, and API key.
- A snippet without tags is sent to that configured OpenAI-compatible endpoint.

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

## Permissions

Accessibility permission is used to simulate copy/paste keyboard events. It does not grant the app permission to upload content.

The floating bubble and menu bar app are local UI surfaces. They do not create network traffic.

## Recommended User Practices

- Keep AI tagging disabled when handling sensitive content.
- Use a provider-specific API key with limited permissions.
- Remove old snippets from the station when they are no longer useful.
- Delete `state.enc` and the `Attachments` folder if you want to clear local data outside the app.
