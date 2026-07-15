# Getting Started

This is the shortest path to understanding Linggan Floating Ball.

## 1. Install

From source:

```bash
git clone https://github.com/IvyCHEN03/clipboard-station.git
cd clipboard-station
./Scripts/install-local.sh
```

If you downloaded a release zip, follow [INSTALL.md](INSTALL.md).

## 2. Open The Station

Look for the small blue floating bubble near the edge of the screen. Click it to open the station.

If the bubble is missing:

```bash
./Scripts/doctor.sh
```

## 3. Try Demo Snippets

In the empty state, click `载入示例`.

You should see sample snippets for:

- AI prompt notes
- table-like copied content
- screenshot insight text

This lets you try the workflow without using private clipboard content.

## 4. Capture Your First Real Snippet

Copy text from any app with `Cmd+C`.

If clipboard monitoring is enabled, the snippet should appear automatically. If not, click the `+` button in the composer to import the current clipboard.

## 5. Compose A Final Prompt

1. Drag snippets into the bottom composer.
2. Click between blocks to add your own text.
3. Reorder blocks if needed.
4. Copy the composed output.

## 6. Optional AI Tags

AI tagging is off by default.

To enable it, open Settings and configure:

- AI Base URL
- model name
- API key

Only snippets that need tags are sent to the configured provider.

## 7. Need Help?

- Read [FAQ.md](FAQ.md).
- Read [USER_GUIDE.md](USER_GUIDE.md).
- Open Settings and click `复制诊断信息` before filing a bug.
