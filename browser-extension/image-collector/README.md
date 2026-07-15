# Linggan Image Collector

Experimental Chrome/Edge extension for collecting image-heavy web pages into one selectable stack.

## What It Does

- Opens from the browser extension button so the page does not show a second Linggan bubble.
- Scans the current post/article/dialog first, then falls back to the page when no post container is detected.
- Keeps each capture as a separate temporary image row.
- Double-clicks a row to expand a selectable grid.
- Uses the post title for each temporary row and its local Downloads subfolder.
- Converts selected images to real PNG files before saving.

This is designed for pages such as image-heavy articles, inspiration boards, and social posts where the page itself does not provide a reliable "download all" button.

## Install For Local Testing

1. Open Chrome or Edge.
2. Go to `chrome://extensions`.
3. Enable Developer mode.
4. Click `Load unpacked`.
5. Select this folder:

```text
browser-extension/image-collector
```

## Use

1. Open an image-heavy web page.
2. Click the Linggan Image Collector button in the browser toolbar, or `Cmd` + click the native Linggan floating bubble when the macOS app is running.
3. Repeat on other posts to keep multiple temporary image rows.
4. Double-click one row to expand its images.
5. Click `全选` once to select everything, double-click it to clear the selection, or click individual image cards.
6. Click `保存选中`.

Images are saved as PNG through the browser download manager under a `LingganImages/...` folder.

Native app bridge: `Cmd` + clicking the macOS Linggan floating bubble sends `Ctrl+Shift+L` to the active browser page.
If `Cmd` + click still opens the station window, quit the old app instance and reinstall/reopen the latest build.

Keyboard fallback while the page is focused: `Ctrl+Shift+L`.

## Limits

- Some sites lazy-load images only after scrolling. Scroll first, then click the browser extension button again to add a fresh row.
- Post detection is heuristic. If a site changes its DOM, the extension may need a selector update.
- The current version is browser-side only. Direct capture from the native macOS floating ball needs a native messaging bridge.
- Blob URLs and protected images may not be downloadable.
- Very small icons, avatars, logos, and sprites are filtered out when possible.
- The extension does not bypass paywalls, authentication, DRM, or site permissions.
- Keep copyright and platform rules in mind before saving or reusing images.
