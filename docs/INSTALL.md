# Install Guide

Linggan Floating Ball is currently unsigned and not notarized. macOS may show extra warnings until signed releases are available.

## Option 1: GitHub Release

1. Download `Linggan-Floating-Ball-<version>.zip` from the GitHub release.
2. Download the matching `.sha256` file.
3. Verify the download:

```bash
cd ~/Downloads
shasum -a 256 -c Linggan-Floating-Ball-<version>.zip.sha256
```

Or, from a cloned checkout, verify both checksum and zip contents:

```bash
./Scripts/verify-release.sh ~/Downloads/Linggan-Floating-Ball-<version>.zip
```

4. Unzip the file.
5. Move `ClipboardStation.app` to `~/Applications` or `/Applications`.
6. Open the app.

If macOS blocks the app because it is unsigned, open System Settings, go to Privacy & Security, and approve opening the app you just downloaded.

## Option 2: Build From Source

Requirements:

- macOS 13+
- Xcode command line tools
- Swift 6 compatible toolchain

```bash
git clone https://github.com/IvyCHEN03/clipboard-station.git
cd clipboard-station
./Scripts/install-local.sh
```

This installs the app into `~/Applications/ClipboardStation.app` and starts a user LaunchAgent so the floating bubble can stay available.

After installing, follow [GETTING_STARTED.md](GETTING_STARTED.md) for the five-minute first run.

## Verify Local Install

Run:

```bash
./Scripts/doctor.sh
```

The doctor should report:

- `OK` for healthy install checks
- `WARN` for anything that needs attention
- a final summary with suggested repair commands

The doctor does not print clipboard contents, snippets, API keys, or encrypted local state. If you paste the output into a GitHub issue, quickly check whether local file paths reveal anything you want to redact.

## Permissions

The app can collect content manually without full automation permissions, but these settings improve the workflow:

- Accessibility: required for automatic paste and simulated copy/paste.
- Launch at login: keeps the floating bubble available after restart.

The app shows permission status in Settings.

## Uninstall

If installed from source:

```bash
./Scripts/uninstall-local.sh
```

The uninstall script removes the app and LaunchAgent but keeps local snippet data. To remove local data too, delete:

```bash
~/Library/Application Support/ClipboardStation
```

## Troubleshooting

- Floating bubble missing: run `./Scripts/install-local.sh`, then `./Scripts/doctor.sh`.
- App opens but paste does not work: grant Accessibility permission.
- macOS says the app is damaged or cannot be opened: confirm you downloaded from the project release, then approve it in Privacy & Security.
- Release checksum fails: delete the zip and download it again.
