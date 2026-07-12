# Support

Linggan Floating Ball is an early open-source macOS utility.

## Before Opening an Issue

Please check:

- The app is running. The floating bubble or menu bar icon should be visible.
- macOS Accessibility permission is granted if automatic paste or simulated copy/paste is not working.
- Clipboard monitoring is enabled in Settings.
- AI tagging is enabled only if you configured Base URL, model, and API key.
- Common questions in `docs/FAQ.md`.
- Private content has been removed from screenshots or logs.

## Where To Ask

- Bugs: open a bug report issue.
- Feature ideas: open a feature request issue.
- Privacy questions: read `PRIVACY.md` first, then open an issue if something is unclear.
- General questions: read `docs/FAQ.md` first.
- Build or install problems: include macOS version, Swift version, and the command output.

## Useful Commands

```bash
swift --version
swift build
./Scripts/package-app.sh
./Scripts/install-local.sh
./Scripts/doctor.sh
```

## Install Repair

If the floating bubble or menu bar icon disappears:

```bash
./Scripts/install-local.sh
```

If you want to remove the local app and launch agent:

```bash
./Scripts/uninstall-local.sh
```

## Data Reset

To clear local app data outside the app, remove:

```text
~/Library/Application Support/ClipboardStation/state.enc
~/Library/Application Support/ClipboardStation/Attachments/
```

The encryption key is stored in macOS Keychain under service `com.local.clipboard-station`.
