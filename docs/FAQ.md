# FAQ

## Does the app upload my clipboard?

No. Linggan Floating Ball is local-first. Clipboard content is stored locally and encrypted on disk. Nothing is uploaded unless you enable AI title/tag generation and configure an API provider.

## What should I do first?

Follow [GETTING_STARTED.md](GETTING_STARTED.md). It walks through install, the floating bubble, demo snippets, real capture, composition, and optional AI tags.

## When does AI tagging send data out?

Only snippets that need AI-generated titles or tags are sent, and only after AI tagging is enabled with a Base URL, model, and API key. Existing tags are preserved and are not regenerated unless the app is asked to process missing tags.

## Why is the floating bubble the primary entry point?

Global shortcuts are fragile on macOS because other apps can reserve the same key combinations. The floating bubble and menu bar icon are more reliable, especially when working across browsers, AI tools, editors, and terminals.

## Is this a replacement for a clipboard manager?

Not exactly. It can collect clipboard content, but the product is optimized for AI-heavy work: collecting fragments, tagging them, reordering them, and composing a final prompt. See [POSITIONING.md](POSITIONING.md) for a deeper comparison.

## Why is the app unsigned?

The project is still early and source-first. Signed and notarized releases are on the roadmap. Until then, macOS may require approval in Privacy & Security before opening a downloaded release build.

## Why does the app allow repeated copies?

Repeated snippets can be meaningful when you are collecting ordered fragments from many AI chats. The app intentionally allows repeated captures instead of deduplicating everything away.

## How are screenshots and spreadsheet snippets handled?

Screenshots are stored as local attachments and shown in the snippet list. Tab-delimited copied cells from spreadsheet apps are stored as table-like text so they can still be searched, tagged, and composed.

## What is included in copied diagnostics?

The Settings button `复制诊断信息` copies non-sensitive support details such as app version, macOS version, snippet counts, permission status, settings toggles, AI provider host, and model name. It does not copy API keys, clipboard contents, full provider URLs, or local encrypted data.

## How do I clear local data?

Inside the app, use the clear action to remove snippets. Outside the app, delete:

```text
~/Library/Application Support/ClipboardStation/state.enc
~/Library/Application Support/ClipboardStation/Attachments/
```

The encryption key is stored in macOS Keychain under service `com.local.clipboard-station`.

## How can I help?

Good early contributions include:

- Reproducing macOS permission edge cases.
- Adding README screenshots or a short demo GIF.
- Improving install docs for non-developers.
- Adding tests for persistence, import detection, and paste behavior.
- Keeping privacy-sensitive behavior local-first and explicit.
