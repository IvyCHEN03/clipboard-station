chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "nativeCaptureRequested") {
    captureFocusedPost()
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ ok: false, error: error?.message || String(error) }));
    return true;
  }

  if (message?.type === "nativeHideRequested") {
    hideFocusedCollector()
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ ok: false, error: error?.message || String(error) }));
    return true;
  }

  if (message?.type === "collectorPanelState") {
    reportPanelState(Boolean(message.open));
    sendResponse({ ok: true });
    return false;
  }

  if (message?.type !== "downloadImages") {
    return false;
  }

  const images = Array.isArray(message.images) ? message.images : [];
  const folder = sanitizePathSegment(message.folder || `linggan-images-${Date.now()}`);

  if (images.length === 0) {
    sendResponse({ ok: false, error: "No images selected." });
    return false;
  }

  downloadImagesAsPNG(images, folder, message.title)
    .then(result => sendResponse(result))
    .catch(error => sendResponse({ ok: false, saved: 0, failed: images.length, error: error?.message || String(error) }));
  return true;
});

chrome.action.onClicked.addListener(async tab => {
  await captureCurrentPost(tab);
});

chrome.runtime.onInstalled.addListener(() => {
  ensureOffscreenBridge();
});

chrome.runtime.onStartup.addListener(() => {
  ensureOffscreenBridge();
});

ensureOffscreenBridge();

chrome.commands.onCommand.addListener(async command => {
  if (command !== "capture-current-post") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  await captureCurrentPost(tab);
});

async function captureCurrentPost(tab) {
  if (!tab?.id) return;
  try {
    await ensureCollectorInjected(tab.id);
    let pageData = null;
    try {
      pageData = await extractCurrentPostData(tab.id);
    } catch (error) {
      console.warn("Linggan Image Collector structured post read failed, using DOM fallback:", error?.message || error);
    }
    chrome.tabs.sendMessage(tab.id, { type: "captureCurrentPost", pageData }, () => {
      if (chrome.runtime.lastError) {
        console.warn("Linggan Image Collector capture failed:", chrome.runtime.lastError.message);
      }
    });
  } catch (error) {
    console.warn("Linggan Image Collector could not run on this page:", error?.message || error);
  }
}

async function extractCurrentPostData(tabId) {
  const [injection] = await chrome.scripting.executeScript({
    target: { tabId },
    world: "MAIN",
    func: () => {
      const state = window.__INITIAL_STATE__;
      const noteID = location.pathname.match(/\/(?:explore|discovery\/item)\/([a-zA-Z0-9]+)/)?.[1] || "";
      const detailMap = state?.note?.noteDetailMap;
      if (!detailMap || typeof detailMap !== "object") return null;
      const details = Object.values(detailMap);
      const detail = detailMap[noteID] || details.find(item => {
        const note = item?.note || item;
        return String(note?.noteId || note?.id || "") === noteID;
      }) || (details.length === 1 ? details[0] : null);
      const note = detail?.note || detail;
      const imageList = note?.imageList || note?.images || detail?.imageList;
      if (!Array.isArray(imageList) || imageList.length === 0) return null;

      const images = imageList.map(image => {
        const infoURLs = Array.isArray(image?.infoList)
          ? image.infoList.map(info => info?.url).filter(Boolean)
          : [];
        const urls = [...new Set([
          image?.urlDefault,
          image?.urlPre,
          image?.url,
          image?.original,
          ...infoURLs
        ].filter(value => typeof value === "string" && value.length > 0))];
        return {
          url: urls[0] || "",
          urls,
          width: Number(image?.width || image?.imageWidth || 0),
          height: Number(image?.height || image?.imageHeight || 0),
          alt: String(note?.title || "")
        };
      }).filter(image => image.url);

      return {
        source: "xiaohongshu-note-state",
        title: String(note?.title || note?.desc || document.title || "").trim().slice(0, 100),
        images
      };
    }
  });
  return injection?.result || null;
}

async function captureFocusedPost() {
  const focusedWindow = await chrome.windows.getLastFocused({ populate: true });
  const tab = focusedWindow?.tabs?.find(candidate => candidate.active);
  if (!tab?.id || !/^https?:/i.test(tab.url || "")) {
    return { ok: false, error: "No active web page." };
  }
  await captureCurrentPost(tab);
  return { ok: true, tabId: tab.id };
}

async function hideFocusedCollector() {
  const focusedWindow = await chrome.windows.getLastFocused({ populate: true });
  const tab = focusedWindow?.tabs?.find(candidate => candidate.active);
  if (!tab?.id) return { ok: false, error: "No active web page." };
  try {
    await chrome.tabs.sendMessage(tab.id, { type: "hideCollectorPanel" });
  } catch {
    // The panel may already be gone after a page navigation.
  }
  await reportPanelState(false);
  return { ok: true };
}

async function reportPanelState(open) {
  try {
    await fetch(`http://127.0.0.1:47831/panel-state?open=${open ? "1" : "0"}`, { cache: "no-store" });
  } catch {
    // The native app may be closed.
  }
}

let creatingOffscreenBridge;

async function ensureOffscreenBridge() {
  if (!chrome.offscreen) return;
  if (await chrome.offscreen.hasDocument()) return;
  if (creatingOffscreenBridge) {
    await creatingOffscreenBridge;
    return;
  }
  creatingOffscreenBridge = chrome.offscreen.createDocument({
    url: "offscreen.html",
    reasons: ["DOM_PARSER"],
    justification: "Listen for local image capture requests from the Linggan macOS app."
  });
  try {
    await creatingOffscreenBridge;
  } finally {
    creatingOffscreenBridge = null;
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

async function downloadImagesAsPNG(images, folder, title) {
  let saved = 0;
  let failed = 0;
  let duplicates = 0;
  const fingerprints = new Set();
  const perceptualHashes = [];
  const baseTitle = sanitizePathSegment(title || "post");
  for (const [index, image] of images.entries()) {
    try {
      const urls = [...new Set([...(Array.isArray(image?.urls) ? image.urls : []), image?.url].filter(isDownloadableURL))];
      if (urls.length === 0) throw new Error("Invalid image URL");
      const png = await convertFirstAvailableToPNG(urls);
      const isVisualDuplicate = perceptualHashes.some(hash => hammingDistance(hash, png.perceptualHash) <= 1);
      if (fingerprints.has(png.fingerprint) || isVisualDuplicate) {
        duplicates += 1;
        continue;
      }
      fingerprints.add(png.fingerprint);
      perceptualHashes.push(png.perceptualHash);
      const filename = `${folder}/${String(saved + 1).padStart(2, "0")}-${baseTitle}.png`;
      await startDownload(png.dataURL, filename);
      saved += 1;
    } catch (error) {
      failed += 1;
      console.warn("Linggan Image Collector PNG save failed:", error?.message || error);
    }
  }
  return {
    ok: saved > 0,
    saved,
    failed,
    duplicates,
    error: saved > 0 ? "" : "图片读取或 PNG 转换失败，请刷新帖子后重试"
  };
}

async function convertFirstAvailableToPNG(urls) {
  let lastError;
  for (const url of urls) {
    try {
      return await convertToPNG(url);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError || new Error("No image URL could be read");
}

async function convertToPNG(url) {
  const response = await fetch(url, { cache: "no-store", credentials: "omit" });
  if (!response.ok) throw new Error(`Image HTTP ${response.status}`);
  const source = await response.blob();
  const bitmap = await createImageBitmap(source);
  try {
    const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    const context = canvas.getContext("2d", { alpha: true });
    context.drawImage(bitmap, 0, 0);
    const png = await canvas.convertToBlob({ type: "image/png" });
    const bytes = new Uint8Array(await png.arrayBuffer());
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
    const fingerprint = [...digest].map(value => value.toString(16).padStart(2, "0")).join("");
    return {
      dataURL: bytesToDataURL(bytes),
      fingerprint,
      perceptualHash: differenceHash(bitmap)
    };
  } finally {
    bitmap.close();
  }
}

function differenceHash(bitmap) {
  const sample = new OffscreenCanvas(9, 8);
  const context = sample.getContext("2d", { alpha: false, willReadFrequently: true });
  context.drawImage(bitmap, 0, 0, 9, 8);
  const pixels = context.getImageData(0, 0, 9, 8).data;
  let bits = "";
  for (let row = 0; row < 8; row += 1) {
    for (let column = 0; column < 8; column += 1) {
      const left = grayscaleAt(pixels, row * 9 + column);
      const right = grayscaleAt(pixels, row * 9 + column + 1);
      bits += left > right ? "1" : "0";
    }
  }
  return bits;
}

function grayscaleAt(pixels, pixelIndex) {
  const offset = pixelIndex * 4;
  return pixels[offset] * 0.299 + pixels[offset + 1] * 0.587 + pixels[offset + 2] * 0.114;
}

function hammingDistance(left, right) {
  if (!left || !right || left.length !== right.length) return Number.POSITIVE_INFINITY;
  let distance = 0;
  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) distance += 1;
  }
  return distance;
}

function bytesToDataURL(bytes) {
  let binary = "";
  const chunkSize = 0x8000;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return `data:image/png;base64,${btoa(binary)}`;
}

function startDownload(url, filename) {
  return new Promise((resolve, reject) => {
    chrome.downloads.download({ url, filename, conflictAction: "uniquify", saveAs: false }, downloadID => {
      const error = chrome.runtime.lastError;
      if (error || !downloadID) {
        reject(new Error(error?.message || "Download could not start"));
      } else {
        resolve(downloadID);
      }
    });
  });
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
