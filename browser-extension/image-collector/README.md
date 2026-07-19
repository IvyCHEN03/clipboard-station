# Linggan Image Collector

Experimental Chrome/Edge extension for collecting image-heavy posts and archiving complete web pages.

## What It Does

- Opens from the browser extension button so the page does not show a second Linggan bubble.
- Scans the current post/article/dialog first, then falls back to the page when no post container is detected.
- Keeps each capture as a separate temporary image row.
- Double-clicks a row to expand a selectable grid.
- Uses the post title for each temporary row and its local Downloads subfolder.
- Converts selected images to real PNG files before saving.
- Saves the current page as both a searchable static HTML snapshot and a full-page PNG screenshot.

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

### Archive A Complete Web Page

1. Open the Linggan image panel on any normal `http` or `https` page.
2. Click `存网页`.
3. Wait for the status line to confirm the archive.

The extension briefly walks the page to wake lazy-loaded images, restores your original scroll position, and saves two files under `Downloads/LingganPages/<time>-<page-title>/`:

- `<page-title>.html`: a static, searchable UTF-8 HTML snapshot with relative links resolved against the original URL.
- `<page-title>-full-page.png`: a high-resolution full-page screenshot from the top of the document to the bottom. The capture scale adapts to the page length so text stays as crisp as Chrome's maximum image size allows.

The panel is hidden from the screenshot. Page scripts, conflicting encoding metadata, Content Security Policy metadata, and form field values are removed from the HTML snapshot. A single UTF-8 declaration is written first in the saved document. The extension attaches Chrome's page debugger only while making the full-page screenshot and detaches immediately afterward; it does not continuously record or monitor the page.

Native app bridge: `Cmd` + clicking the macOS Linggan floating bubble sends `Ctrl+Shift+L` to the active browser page.
If `Cmd` + click still opens the station window, quit the old app instance and reinstall/reopen the latest build.

Keyboard fallback while the page is focused: `Ctrl+Shift+L`.

## Limits

- Some sites lazy-load images only after scrolling. Scroll first, then click the browser extension button again to add a fresh row.
- Post detection is heuristic. If a site changes its DOM, the extension may need a selector update.
- The current version is browser-side only. Direct capture from the native macOS floating ball needs a native messaging bridge.
- Blob URLs and protected images may not be downloadable.
- Very tall pages may exceed Chrome's maximum single-image dimensions. In that case the HTML file is still the more complete archive.
- The HTML file is a static snapshot, not an offline clone of server-side behavior. Videos, canvases, login state, and script-driven interactions may not replay.
- Very small icons, avatars, logos, and sprites are filtered out when possible.
- The extension does not bypass paywalls, authentication, DRM, or site permissions.
- Keep copyright and platform rules in mind before saving or reusing images.
