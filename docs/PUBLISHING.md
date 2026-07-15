# Publishing Guide

Use this guide when pushing local work to GitHub and cutting the first prerelease.

The project handles clipboard content, screenshots, optional AI provider settings, and local app data, so publishing should be slow, explicit, and privacy-aware.

## 1. Revoke Exposed Tokens

If any GitHub personal access token, AI API key, or provider secret has been pasted into a chat, terminal log, issue, screenshot, or repository file, treat it as exposed.

Before pushing:

1. Revoke the exposed token in the provider dashboard.
2. Create a fresh token only if it is still needed.
3. Do not reuse the old token, even if it never reached git.
4. Run:

```bash
./Scripts/check-secrets.sh
```

## 2. Use A Narrow GitHub Token

Prefer GitHub CLI or a fine-grained personal access token scoped only to this repository.

Suggested fine-grained permissions for publishing this repo:

- Repository access: `IvyCHEN03/clipboard-station` only.
- Contents: read and write.
- Metadata: read.
- Actions: read, if checking workflow status through API tooling.

Avoid broad account-wide tokens. Do not paste tokens into issue bodies, README examples, screenshots, release notes, or committed shell scripts.

## 3. Local Preflight

From the repository root:

```bash
git status --short --branch
./Scripts/check-project.sh
./Scripts/make-release-notes.sh v0.4.0
./Scripts/make-release-zip.sh v0.4.0
./Scripts/verify-release.sh .build/dist/Linggan-Floating-Ball-v0.4.0.zip
```

Review:

- `git status` contains only intentional changes before committing.
- The release notes mention unsigned/not-notarized builds.
- The zip and `.sha256` file exist under `.build/dist/`.
- No `.build/` artifacts are staged for commit.

## 4. Recommended Publish Command

After committing and authenticating GitHub safely, use the prerelease helper:

```bash
./Scripts/publish-prerelease.sh --apply v0.4.0
```

Without `--apply`, it only prints the plan:

```bash
./Scripts/publish-prerelease.sh v0.4.0
```

The apply run checks the project, builds release assets, verifies the zip, pushes `main`, creates the tag, and pushes the tag. The GitHub release workflow then creates the prerelease assets.

## 5. Manual Push Main

After committing:

```bash
git push origin main
```

Then check GitHub Actions CI for `main`. Do not tag a release until CI is green.

## 6. Manual Prerelease Tag

The release workflow runs on tags matching `v*`.

```bash
git tag v0.4.0
git push origin v0.4.0
```

The GitHub release workflow should:

1. Run the full project check.
2. Build `Linggan-Floating-Ball-v0.4.0.zip`.
3. Build `Linggan-Floating-Ball-v0.4.0.zip.sha256`.
4. Generate release notes from `CHANGELOG.md`.
5. Publish a prerelease with both assets attached.

## 7. Verify The GitHub Release

Before sharing the repository broadly:

- Confirm the release is marked prerelease.
- Download the zip and `.sha256` file from GitHub.
- Verify checksum locally:

```bash
cd ~/Downloads
shasum -a 256 -c Linggan-Floating-Ball-v0.4.0.zip.sha256
```

- Unzip and confirm `ClipboardStation.app` is present.
- Confirm release notes include privacy notes and unsigned-install limitations.
- Confirm README badges render and the release badge links to the workflow.

## 8. Update Repository Profile

After the first prerelease exists:

- Set the repository Website field to the releases page.
- Apply topics from [REPOSITORY_PROFILE.md](REPOSITORY_PROFILE.md).
- Add the README hero image or a redacted app screenshot as social preview.
- Pin the repository on the GitHub profile.

## 9. First Public Share

Share only after:

- The release asset downloads correctly.
- The install guide is accurate.
- Issue templates are live.
- You can respond to issues for the first week.

Use the copy in [OPEN_SOURCE_GROWTH.md](OPEN_SOURCE_GROWTH.md) and [REPOSITORY_PROFILE.md](REPOSITORY_PROFILE.md).

## Rollback

If a release asset is wrong:

1. Mark the GitHub release as draft or delete the release.
2. Delete the bad tag locally and remotely if needed:

```bash
git tag -d v0.4.0
git push origin :refs/tags/v0.4.0
```

3. Fix the issue.
4. Re-run local preflight.
5. Publish a new tag only after the fix is verified.

If a secret is published, revoke it first, then remove it from public content. Rotating the credential matters more than deleting the visible text.
