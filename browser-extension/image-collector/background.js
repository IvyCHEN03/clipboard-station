chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "downloadImages") {
    return false;
  }

  const images = Array.isArray(message.images) ? message.images : [];
  const folder = sanitizePathSegment(message.folder || `linggan-images-${Date.now()}`);

  if (images.length === 0) {
    sendResponse({ ok: false, error: "No images selected." });
    return false;
  }

  let started = 0;
  let failed = 0;

  for (const [index, image] of images.entries()) {
    const url = image?.url;
    if (!url || !isDownloadableURL(url)) {
      failed += 1;
      continue;
    }

    const extension = extensionForURL(url, image?.type);
    const baseName = sanitizePathSegment(image?.name || image?.alt || `image-${index + 1}`);
    const filename = `${folder}/${String(index + 1).padStart(2, "0")}-${baseName}.${extension}`;

    chrome.downloads.download(
      {
        url,
        filename,
        conflictAction: "uniquify",
        saveAs: false
      },
      () => {
        if (chrome.runtime.lastError) {
          console.warn("Linggan Image Collector download failed:", chrome.runtime.lastError.message);
        }
      }
    );
    started += 1;
  }

  sendResponse({ ok: started > 0, started, failed });
  return false;
});

chrome.action.onClicked.addListener(async tab => {
  await captureCurrentPost(tab);
});

chrome.commands.onCommand.addListener(async command => {
  if (command !== "capture-current-post") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  await captureCurrentPost(tab);
});

async function captureCurrentPost(tab) {
  if (!tab?.id) return;
  try {
    await ensureCollectorInjected(tab.id);
    chrome.tabs.sendMessage(tab.id, { type: "captureCurrentPost" }, () => {
      if (chrome.runtime.lastError) {
        console.warn("Linggan Image Collector capture failed:", chrome.runtime.lastError.message);
      }
    });
  } catch (error) {
    console.warn("Linggan Image Collector could not run on this page:", error?.message || error);
  }
}

async function ensureCollectorInjected(tabId) {
  await chrome.scripting.insertCSS({
    target: { tabId },
    files: ["styles.css"]
  });

  await chrome.scripting.executeScript({
    target: { tabId },
    files: ["content.js"]
  });
}

function isDownloadableURL(url) {
  return /^https?:\/\//i.test(url) || /^data:image\//i.test(url);
}

function extensionForURL(url, mimeType) {
  if (mimeType?.includes("png")) return "png";
  if (mimeType?.includes("webp")) return "webp";
  if (mimeType?.includes("gif")) return "gif";
  if (mimeType?.includes("jpeg") || mimeType?.includes("jpg")) return "jpg";

  const clean = url.split(/[?#]/)[0].toLowerCase();
  const match = clean.match(/\.([a-z0-9]{2,5})$/);
  if (match && ["jpg", "jpeg", "png", "webp", "gif", "avif"].includes(match[1])) {
    return match[1] === "jpeg" ? "jpg" : match[1];
  }
  return "jpg";
}

function sanitizePathSegment(value) {
  return String(value)
    .trim()
    .replace(/[\\/:*?"<>|]+/g, "-")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80) || "image";
}
