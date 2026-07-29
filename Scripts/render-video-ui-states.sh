#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${LINGGAN_VIDEO_UI_DIR:-/private/tmp/linggan-video-ui}"
states=(reset filter search first-block second-block bridge-text polishing polished copied)

mkdir -p "$output_dir"
cd "$repo_root"

for state in "${states[@]}"; do
  echo "Rendering actual UI state: $state"
  CLIPBOARD_STATION_VIDEO_DEMO=1 \
  CLIPBOARD_STATION_RENDER_SCREENSHOT="$output_dir/$state.png" \
  CLIPBOARD_STATION_RENDER_SCREENSHOT_STATE="$state" \
    swift test --filter MarketingScreenshotTests/testRenderLatestInterfaceWhenRequested
done

echo "Rendered actual UI states to $output_dir"
