# Release Notes Template

Use this template for each GitHub Release. Keep it short, practical, and privacy-aware.

Maintainers can generate a draft from `CHANGELOG.md`:

```bash
./Scripts/make-release-notes.sh vX.Y.Z
```

````markdown
# Linggan Floating Ball <version>

Linggan Floating Ball is a local-first macOS clipboard station for collecting text, screenshots, and table snippets while working across multiple AI chats.

## Who Should Install This

- People who are comfortable running an unsigned macOS app.
- People who want a local clipboard station for AI prompt composition.
- People who understand that optional AI tagging sends selected snippet text to their configured provider.

## Highlights

- <One user-facing improvement>
- <One reliability or install improvement>
- <One documentation or contributor improvement>

## Download

Download:

- `Linggan-Floating-Ball-<version>.zip`
- `Linggan-Floating-Ball-<version>.zip.sha256`

Verify the checksum:

```bash
shasum -a 256 -c Linggan-Floating-Ball-<version>.zip.sha256
```

From a cloned checkout, maintainers can also run:

```bash
./Scripts/verify-release.sh path/to/Linggan-Floating-Ball-<version>.zip
```

Then unzip and open `ClipboardStation.app`.

## Important Install Note

This release is currently unsigned and not notarized. macOS may block the first launch. If that happens, open System Settings > Privacy & Security and allow the app manually.

For full install and uninstall steps, read `docs/INSTALL.md`.

## Privacy Notes

- Clipboard content stays local by default.
- Snippets are stored locally with Keychain-backed encryption.
- AI tagging is off by default.
- If AI tagging is enabled, snippet text is sent only to the configured OpenAI-compatible endpoint.
- API keys are stored in macOS Keychain.

Read `PRIVACY.md` before using AI tagging with sensitive content.

## Known Limitations

- The app is not signed or notarized yet.
- Global shortcuts can conflict with other apps; the floating bubble is the recommended entry point.
- OCR quality depends on the copied screenshot.

## Feedback

Please use the GitHub issue templates:

- Bug report for broken behavior.
- Usage question for setup or workflow questions.
- Feature request for product ideas.

Do not paste private clipboard contents, API keys, or sensitive screenshots into public issues.
````

## Maintainer Checklist

Before publishing:

- Replace every `<version>` placeholder.
- Replace highlight placeholders with concrete user-facing changes.
- Check that `CHANGELOG.md` has a matching entry.
- Upload both the `.zip` and `.sha256` assets.
- Confirm the release is marked prerelease until signing and notarization are available.
