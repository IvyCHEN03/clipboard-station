# Demo Script

Use this script to record a short GIF, video, or screenshot set for README, releases, and social posts.

For repository launch steps and channel planning, see [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md).

## One-Sentence Pitch

Linggan Floating Ball is a local-first macOS inspiration station for collecting text, screenshots, table snippets, and entire image-heavy posts.

## Demo+ Image Collector

Target length: 10-15 seconds.

Hook: `One bubble. The whole post.`

1. Open a synthetic or fully redacted multi-image post.
2. `Cmd` + click the small blue Linggan bubble.
3. Show one titled temporary image row appear.
4. Double-click the row to expand all post images.
5. Click two individual image cards to change the selection.
6. Click `Save PNG` and show the clean local image set.
7. Click the Linggan bubble once to collapse the image panel.

Do not show browser tabs, account avatars, usernames, tokens, or real saved content. Use [image-collector-demo.svg](assets/image-collector-demo.svg) as the README fallback until a real recording passes the privacy checklist.

## README Hero GIF

Target length: 8-15 seconds.

Goal: make a new visitor understand the product before reading the README.

Recommended sequence:

1. Show the small blue floating bubble.
2. Click it to open the station with demo snippets already loaded.
3. Copy one short text fragment from a redacted browser or note window.
4. Show the new snippet appear in the station.
5. Drag two or three snippets into the composer.
6. Click between blocks and type a short bridge phrase.
7. Click copy on the composed output.

Keep the GIF focused. Do not show Settings, AI provider setup, or long menus in the README hero. Those details belong in screenshots or docs, not the first visual.

## 60-Second Flow

1. Show the small blue floating bubble on the desktop.
2. Start from the empty state and click `载入示例`.
3. Show text, table-like, and screenshot-insight examples with tags.
4. Open two or three AI/chat/browser windows with useful text.
5. Copy a paragraph. Show it appears as a text snippet.
6. Copy the same paragraph again. Show repeated captures are allowed.
7. Copy spreadsheet-like cells. Show the table snippet.
8. Copy or import a screenshot. Show the image preview.
9. Click a time filter and two tag chips. Show the filtered count in the header.
10. Drag three snippets into the bottom composer.
11. Click between blocks and add a short custom sentence.
12. Copy the composed output.
13. Open Settings and show local status, launch-at-login, and optional AI tagging.

## Screenshot Set

Capture these still images for a polished GitHub README:

- `workflow-preview.svg`: synthetic overview diagram used until a real GIF exists.
- `image-collector-demo.svg`: synthetic Demo+ preview for whole-post image capture.
- `01-empty-onboarding.png`: first-run empty state with the quick-start steps.
- `02-collected-snippets.png`: text, screenshot, and table snippets in one list.
- `03-filtered-tags.png`: time filter plus multiple selected tag chips.
- `04-composer-blocks.png`: colored blocks with text inserted between them.
- `05-settings-status.png`: running status, shortcut status, accessibility status, and AI settings.

Recommended screenshot width: 1200-1600 px. Redact private clipboard content before committing images.

## Asset Acceptance Checklist

Before adding a GIF or screenshot to the repository:

- [ ] Uses demo snippets, synthetic text, or fully redacted content.
- [ ] Shows the floating bubble or station UI within the first two seconds.
- [ ] Shows the composer blocks, not only the snippet list.
- [ ] Does not show API keys, local file paths, account names, billing pages, private browser tabs, or provider dashboards.
- [ ] GIF is short enough to load quickly on GitHub.
- [ ] Still screenshots are readable at GitHub README width.
- [ ] File names match [assets/README.md](assets/README.md).
- [ ] README is updated to use `docs/assets/hero.gif` only after the GIF is stronger than `hero-preview.svg`.

## Release Notes Copy

```text
Linggan Floating Ball v0.4.0 turns your clipboard into a small local station for AI-heavy work. Capture repeated text snippets, screenshots, and table-like content; filter by tags and time; then assemble a final prompt with colored blocks. Data stays local by default, and AI tags only run when configured.
```

## Privacy Line

Use this line whenever sharing the app publicly:

```text
Local-first by default: clipboard content is encrypted on disk and never uploaded unless optional AI tagging is enabled.
```

## What Not To Show

- Real API keys.
- Private clipboard content.
- Personal screenshots with names, emails, account numbers, or tokens.
- Provider billing pages.
