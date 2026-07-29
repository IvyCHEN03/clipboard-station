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

This installs and starts `ClipboardStation.app` beside the cloned source directory. Enable `开机启动` in the app when you want it to create a user LaunchAgent and stay available after login.

The install script rebuilds the packaged app every time before replacing that local app. If you pull new changes, edit the source, or move the checkout, run the same command again to refresh the app, update the LaunchAgent path, and restart it:

```bash
./Scripts/install-local.sh
```

To install somewhere else intentionally:

```bash
LINGGAN_INSTALL_DIR="$HOME/Applications" ./Scripts/install-local.sh
```

After installing, follow [GETTING_STARTED.md](GETTING_STARTED.md) for the five-minute first run.

## Install Or Repair The Chrome Extension

The native install script also refreshes a stable extension copy at:

```text
~/Library/Application Support/ClipboardStation/BrowserExtension
```

Open `chrome://extensions`, enable Developer mode, and use `Load unpacked` to
select that directory. If an older Linggan extension still points to a source
folder that was moved, remove the old card first.

For later updates, run:

```bash
./Scripts/install-browser-extension.sh --reveal
```

Then click `Reload` on the existing Linggan extension card. You do not need to
choose the directory again.

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
- Local changes do not appear: run `./Scripts/install-local.sh` again so the app is rebuilt, reinstalled, and restarted.
- Chrome extension cannot update: remove the unpacked copy that points to the old checkout, then load `~/Library/Application Support/ClipboardStation/BrowserExtension`.
- App opens but paste does not work: grant Accessibility permission.
- macOS says the app is damaged or cannot be opened: confirm you downloaded from the project release, then approve it in Privacy & Security.
- Release checksum fails: delete the zip and download it again.
