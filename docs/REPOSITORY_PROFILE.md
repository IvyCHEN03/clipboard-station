# Repository Profile

Use this page to configure the GitHub repository profile before a public launch.

## About Sidebar

Description:

```text
Local-first macOS clipboard station for working across many AI chats.
```

Website:

```text
https://github.com/IvyCHEN03/clipboard-station/releases
```

Use the releases URL only after the first release asset exists. Until then, leave Website blank or point to the README.

## Topics

Recommended topics:

```text
macos
swift
swiftui
clipboard
menubar-app
ai-tools
local-first
productivity
privacy
prompt-engineering
```

## Social Preview

Use one of these:

- A redacted screenshot showing the floating bubble, snippet list, and composer.
- The blue bubble icon on a simple light background.
- The workflow preview from `docs/assets/workflow-preview.svg`, exported as a PNG.

Avoid screenshots that include private clipboard text, API keys, local file paths, browser tabs, or provider dashboards.

## Pinned Repository Copy

Short copy for a GitHub profile pin:

```text
Local-first macOS clipboard station for collecting, tagging, and composing fragments across many AI chats.
```

## README First-Screen Checklist

The first screen should show:

- What the app does.
- That it is macOS and local-first.
- The floating bubble/product visual.
- A quick-start path.
- Privacy boundary: no upload unless AI tagging is enabled.
- Current status: usable pre-1.0, unsigned builds, and optional AI tagging.
- A clear next click for users and contributors.

Use [OPEN_SOURCE_GROWTH.md](OPEN_SOURCE_GROWTH.md) to evaluate whether the first 10 seconds, first 2 minutes, first successful moment, and trust moment are all supported.

## Launch Post Copy

Short post:

```text
I built Linggan Floating Ball: a local-first macOS clipboard station for people working across many AI chats. It captures repeated text snippets, screenshots, and table-like content, then lets you reorder them into a final prompt. Local by default; AI tags are optional.
```

Longer post:

```text
When I work across ChatGPT, Claude, Codex, browsers, notes, and spreadsheets, the normal clipboard is too small. Linggan Floating Ball is a tiny macOS menu bar app that keeps copied fragments visible, searchable, taggable, reorderable, and ready to compose into one final prompt.

It supports text, screenshots, table-like copied content, local encrypted persistence, Markdown export, JSON backup, and optional AI-generated titles/tags through an OpenAI-compatible endpoint.

The default stance is local-first: no cloud sync and no uploads unless AI tagging is explicitly enabled.
```

## Launch Timing

Do not do a broad launch until:

- The README has a visible demo or workflow preview.
- A release zip and checksum are available.
- Unsigned-install limitations are clear.
- `./Scripts/check-project.sh` passes.
- The issue templates and labels are configured.
- The launch copy and feedback plan in [OPEN_SOURCE_GROWTH.md](OPEN_SOURCE_GROWTH.md) are ready.
