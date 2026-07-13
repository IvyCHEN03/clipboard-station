# Linggan Image Collector

Experimental Chrome/Edge extension for collecting image-heavy web pages into one selectable stack.

## What It Does

- Adds a small Linggan-style blue bubble to web pages.
- Scans the current post/article/dialog first, then falls back to the page when no post container is detected.
- Collapses found images into one stacked image cell.
- Double-clicks the stack to expand a selectable grid.
- Saves selected images into a local Downloads subfolder.

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
2. Click the blue Linggan bubble, or `Cmd` + click it to collect and expand the current post immediately.
3. Double-click the stacked image cell.
4. Select or unselect images.
5. Click `保存选中`.

Images are saved through the browser download manager under a `LingganImages/...` folder.

## Limits

- Some sites lazy-load images only after scrolling. Scroll first, then click `刷新`.
- Post detection is heuristic. If a site changes its DOM, the extension may need a selector update.
- Blob URLs and protected images may not be downloadable.
- Very small icons, avatars, logos, and sprites are filtered out when possible.
- The extension does not bypass paywalls, authentication, DRM, or site permissions.
- Keep copyright and platform rules in mind before saving or reusing images.
