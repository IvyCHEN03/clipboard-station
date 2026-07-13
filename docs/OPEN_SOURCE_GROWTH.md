# Open Source Growth Plan

This document turns the product positioning into a practical launch and growth plan for GitHub stars, first users, and useful community feedback.

## Product Promise

One sentence:

> Linggan Floating Ball is a local-first macOS clipboard station for people collecting, tagging, reordering, and composing fragments across many AI chats.

The promise should stay narrow. The project wins when a visitor understands that it is not another generic clipboard manager; it is working memory for AI-heavy research and prompt composition.

## Ideal First Users

- People comparing answers across ChatGPT, Claude, Codex, Gemini, Perplexity, notes, and browsers.
- Students and researchers collecting quotes, tables, screenshots, and summaries before writing a final prompt.
- Builders and operators who copy repeated IDs, logs, snippets, or instructions into AI tools.
- Privacy-sensitive users who do not want a cloud clipboard by default.

Avoid messaging that suggests the app is for every clipboard history use case. A focused tool is easier to trust and easier to recommend.

## Star Conversion Funnel

### 1. First 10 Seconds

The repository must answer:

- What is it?
- Who is it for?
- Why not just use clipboard history?
- Is my clipboard uploaded anywhere?

Current assets that support this:

- README tagline and 30-second tour.
- Workflow preview image.
- Privacy section and privacy document.
- Positioning document.

Still needed:

- A real redacted screenshot or short GIF above the fold.
- A release badge that points to a usable prerelease once the first public zip exists.

### 2. First 2 Minutes

The visitor should be able to try the app without guessing:

- Download a release zip when available.
- Or clone and run `./Scripts/install-local.sh`.
- Run `./Scripts/doctor.sh` if the bubble does not appear.
- Understand that the build is unsigned and may need macOS approval.

Current assets that support this:

- Install guide.
- Getting started guide.
- Doctor script.
- Release verifier script.

Still needed:

- A copied-and-pasted release note in the first GitHub prerelease.
- A visible "Known limitations" block in each release.

### 3. First Successful Moment

The first successful moment should be:

> I copied three fragments, saw them appear, dragged them into blocks, added a sentence between them, and pasted the final prompt.

Product details that protect this moment:

- Floating bubble as the stable entry point.
- Demo snippets for safe first exploration.
- Repeated captures are allowed.
- Plain text, screenshots, and spreadsheet-like snippets are visible in one list.
- Search, tags, and recent-time filters reduce the fear that content disappeared.

### 4. Trust Moment

Trust is the main adoption bottleneck because the app handles clipboard content.

The repository should keep repeating these facts in the right places:

- Local-first storage.
- Encrypted local persistence.
- No telemetry.
- No cloud sync.
- AI tagging is off by default.
- API keys live in Keychain.
- Diagnostics redact sensitive data.

Trust assets:

- [Privacy](../PRIVACY.md)
- [Security](../SECURITY.md)
- [FAQ](FAQ.md)
- [Architecture](ARCHITECTURE.md)
- `./Scripts/check-project.sh`

## Launch Sequence

### Prelaunch

- Finish a clean prerelease zip and checksum.
- Add one redacted screenshot of the station with demo snippets.
- Add one short GIF showing copy -> collect -> compose -> paste.
- Make sure README links and badges render on GitHub.
- Revoke any exposed GitHub tokens and use a fresh fine-grained token for publishing.
- Follow [PUBLISHING.md](PUBLISHING.md) for safe push, tag, prerelease, and rollback steps.

### First GitHub Release

Release title:

```text
Linggan Floating Ball v0.4.0 - local-first AI clipboard station prerelease
```

Release notes must include:

- One-sentence product promise.
- Installation steps.
- Checksum verification.
- Unsigned/not-notarized warning.
- Privacy note.
- Known limitations.
- Feedback request.

### First Public Post

Core post:

```text
I built Linggan Floating Ball, a local-first macOS clipboard station for AI-heavy work. It lets you collect repeated text, screenshots, and table snippets while comparing multiple AI chats, then reorder them into a final prompt. No cloud sync; AI tags are optional.
```

Add a GIF or screenshot before posting to broad audiences.

## Community Strategy

Good first issues should be small, testable, and friendly:

- Add accessibility labels.
- Improve install troubleshooting wording.
- Add pasteboard import edge-case tests.
- Add redacted demo assets.
- Improve keyboard navigation.

Avoid broad issues like "make AI better" or "redesign UI"; they are too vague for new contributors.

## Product Metrics

Because there is no telemetry, use repository-visible signals:

- Stars after README/demo changes.
- Release downloads.
- Issues mentioning install friction.
- Issues mentioning permission confusion.
- PRs from first-time contributors.
- Repeated questions that should become FAQ entries.

## Messaging Guardrails

Say:

- "Local-first"
- "AI tagging is optional"
- "For composing fragments across many AI chats"
- "Floating bubble is the recommended entry point"

Avoid:

- "The best clipboard manager"
- "Fully secure"
- "Works everywhere"
- "One shortcut solves everything"

The strongest public story is narrow, honest, and immediately useful.
