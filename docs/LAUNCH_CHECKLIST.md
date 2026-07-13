# GitHub Launch Checklist

Use this checklist when preparing the repository for a public push, first release, or social launch.

## Repository Profile

- [ ] Apply the About sidebar, topics, social preview, and pinned-repo copy from [REPOSITORY_PROFILE.md](REPOSITORY_PROFILE.md).
- [ ] Social preview image uses the blue bubble icon or a redacted app screenshot.
- [ ] README badges render correctly.
- [ ] README first screen shows the product value before implementation details.
- [ ] [POSITIONING.md](POSITIONING.md) clearly explains who the app is and is not for.

## Release Readiness

- [ ] Complete [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).
- [ ] Run:

```bash
./Scripts/check-project.sh
./Scripts/make-release-zip.sh v0.4.0
```

- [ ] Verify `.zip` and `.zip.sha256` are attached to the release.
- [ ] Mark the release as prerelease while builds are unsigned.
- [ ] Include the privacy line from [DEMO.md](DEMO.md).
- [ ] Mention that signed and notarized releases are on the roadmap.

## Visual Assets

- [ ] Add `docs/assets/hero.gif`.
- [ ] Add the five screenshots listed in [DEMO.md](DEMO.md).
- [ ] Use synthetic or redacted content only.
- [ ] Keep GIF/video under a size that loads quickly on GitHub.
- [ ] Update README Demo section after assets exist.

## First Public Post

Core message:

```text
I built Linggan Floating Ball: a local-first macOS clipboard station for people working across many AI chats. It captures repeated text snippets, screenshots, and table-like content, then lets you reorder them into a final prompt. Local by default; AI tags are optional.
```

Suggested channels:

- GitHub personal profile pins.
- X/Twitter or Threads.
- LinkedIn.
- Reddit communities that allow project sharing.
- Hacker News `Show HN`, only after a demo GIF or release asset exists.
- Product Hunt, after signed/notarized release or a very clear unsigned-install note.

## First Week Maintenance

- [ ] Watch new issues daily.
- [ ] Triage feedback with [TRIAGE.md](TRIAGE.md).
- [ ] Ask users to paste copied diagnostics for bug reports.
- [ ] Convert repeated questions into [FAQ.md](FAQ.md) updates.
- [ ] Convert repeated setup issues into [INSTALL.md](INSTALL.md) updates.
- [ ] Review Dependabot PRs for GitHub Actions updates.
- [ ] Tag approachable fixes as good first issues.
- [ ] Keep scope tight: reliability and onboarding before large new features.

## Star Conversion Notes

The repository should make these promises obvious within 30 seconds:

- What it does: collect and compose fragments while using many AI chats.
- Who it is for: people comparing, extracting, and recombining AI outputs.
- Why it is safe: local-first, encrypted persistence, optional AI tagging.
- How to try it: release zip or source install.
- How to trust it: tests, checks, privacy docs, diagnostics, release checksum.
- How to help: good first issues and small scoped contribution paths.
