let pollInFlight = false;

window.setInterval(async () => {
  if (pollInFlight) return;
  pollInFlight = true;
  try {
    const response = await fetch("http://127.0.0.1:47831/capture", { cache: "no-store" });
    const payload = await response.json();
    if (payload?.capture === true) {
      await chrome.runtime.sendMessage({ type: "nativeCaptureRequested" });
    }
    if (payload?.hide === true) {
      await chrome.runtime.sendMessage({ type: "nativeHideRequested" });
    }
  } catch {
    // The macOS app may be closed; retry quietly on the next interval.
  } finally {
    pollInFlight = false;
  }
}, 400);
