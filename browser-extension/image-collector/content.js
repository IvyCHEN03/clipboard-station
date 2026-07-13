(() => {
  const ROOT_ID = "linggan-image-collector-root";
  const MIN_IMAGE_EDGE = 120;
  const POST_SELECTORS = [
    "[role='dialog']",
    "[data-e2e='note-detail']",
    "[class*='note-container']",
    "[class*='note-detail']",
    "[class*='note-content']",
    "[class*='media-container']",
    "[class*='feed-detail']",
    "[class*='post-detail']",
    "[class*='swiper']",
    "[class*='article']",
    "article",
    "main"
  ];
  const state = {
    batches: [],
    activeBatchID: "",
    status: "",
    autoHideTrigger: false
  };

  if (document.getElementById(ROOT_ID)) {
    return;
  }

  const root = document.createElement("div");
  root.id = ROOT_ID;
  root.innerHTML = `
    <button class="lic-trigger lic-hidden" type="button" title="灵感收图：点击暂存当前帖子" aria-label="灵感收图">
      <span class="lic-bubble-mark">✦</span>
    </button>
    <section class="lic-panel lic-hidden" aria-label="灵感图片采集器">
      <div class="lic-header">
        <div>
          <div class="lic-title">灵感图片暂存</div>
          <div class="lic-subtitle">每个帖子一行，双击展开</div>
        </div>
        <div class="lic-actions">
          <button class="lic-small" type="button" data-action="capture">收图</button>
          <button class="lic-small" type="button" data-action="close">收起</button>
        </div>
      </div>
      <div class="lic-batches"></div>
      <div class="lic-status"></div>
    </section>
  `;
  (document.body || document.documentElement).appendChild(root);

  const trigger = root.querySelector(".lic-trigger");
  const panel = root.querySelector(".lic-panel");
  const batches = root.querySelector(".lic-batches");
  const status = root.querySelector(".lic-status");

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type !== "captureCurrentPost") return false;
    captureBatch();
    panel.classList.remove("lic-hidden");
    sendResponse({ ok: true });
    return false;
  });

  window.addEventListener("keydown", event => {
    if (event.ctrlKey && event.shiftKey && event.key.toLowerCase() === "l") {
      event.preventDefault();
      captureBatch();
      panel.classList.remove("lic-hidden");
    }
  });

  trigger.addEventListener("click", event => {
    captureBatch();
    panel.classList.remove("lic-hidden");
  });

  batches.addEventListener("dblclick", event => {
    const row = event.target?.closest?.(".lic-batch");
    if (!row) return;
    state.activeBatchID = state.activeBatchID === row.dataset.batchId ? "" : row.dataset.batchId;
    render();
  });

  panel.addEventListener("click", event => {
    const button = event.target?.closest?.("button[data-action]");
    const action = button?.dataset?.action;
    if (!action) return;
    event.preventDefault();
    event.stopPropagation();

    if (action === "capture") {
      captureBatch();
    } else if (action === "close") {
      panel.classList.add("lic-hidden");
      render();
    } else if (action === "select-all") {
      const batch = batchForButton(button);
      batch?.images.forEach(image => batch.selected.add(image.id));
      render();
    } else if (action === "clear") {
      batchForButton(button)?.selected.clear();
      render();
    } else if (action === "remove-batch") {
      const batch = batchForButton(button);
      state.batches = state.batches.filter(item => item.id !== batch?.id);
      if (state.activeBatchID === batch?.id) state.activeBatchID = "";
      render();
    } else if (action === "download") {
      const batch = batchForButton(button);
      if (batch) downloadSelected(batch);
    }
  });

  batches.addEventListener("change", event => {
    if (!event.target?.matches("input[type='checkbox']")) return;
    const batch = event.target.closest(".lic-batch")?.dataset?.batchId;
    const activeBatch = state.batches.find(item => item.id === batch);
    if (!activeBatch) return;
    const id = event.target.value;
    if (event.target.checked) {
      activeBatch.selected.add(id);
    } else {
      activeBatch.selected.delete(id);
    }
    renderStatus();
  });

  function captureBatch() {
    const result = collectImages();
    const batch = {
      id: `batch-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      title: `${result.sourceLabel} ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`,
      sourceLabel: result.sourceLabel,
      images: result.images,
      selected: new Set(result.images.map(image => image.id))
    };
    if (result.images.length > 0) {
      state.batches.unshift(batch);
      state.activeBatchID = batch.id;
    }
    state.status = result.images.length
      ? `已暂存 ${batch.title} · ${result.images.length} 张`
      : "没有找到适合保存的大图";
    render();
  }

  function render() {
    renderBatches();
    renderStatus();
  }

  function renderBatches() {
    batches.innerHTML = "";

    if (state.batches.length === 0) {
      batches.innerHTML = `
        <div class="lic-empty-text">还没有图片暂存。点“收图”保存当前帖子。</div>
      `;
      return;
    }

    for (const batch of state.batches) {
      const expanded = state.activeBatchID === batch.id;
      const row = document.createElement("section");
      row.className = `lic-batch${expanded ? " lic-batch-expanded" : ""}`;
      row.dataset.batchId = batch.id;
      row.innerHTML = `
        <div class="lic-batch-row" title="双击展开这一行">
          ${renderStackHTML(batch)}
          <div class="lic-batch-meta">
            <strong>${escapeHTML(batch.title)}</strong>
            <span>${batch.images.length} 张 · 已选 ${batch.selected.size} 张</span>
          </div>
        </div>
        <div class="lic-toolbar${expanded ? "" : " lic-hidden"}">
          <button class="lic-small" type="button" data-action="select-all">全选</button>
          <button class="lic-small" type="button" data-action="clear">取消</button>
          <button class="lic-small" type="button" data-action="remove-batch">移除</button>
          <button class="lic-primary" type="button" data-action="download">保存选中</button>
        </div>
        <div class="lic-grid${expanded ? "" : " lic-hidden"}">
          ${batch.images.map(image => `
            <label class="lic-item">
              <input type="checkbox" value="${escapeAttribute(image.id)}" ${batch.selected.has(image.id) ? "checked" : ""}>
              <img src="${escapeAttribute(image.url)}" alt="${escapeAttribute(image.alt || "collected image")}">
              <span>${escapeHTML(image.label)}</span>
            </label>
          `).join("")}
        </div>
      `;
      batches.appendChild(row);
    }
  }

  function renderStackHTML(batch) {
    const preview = batch.images.slice(0, 4).map((image, index) => `
      <img src="${escapeAttribute(image.url)}" alt="${escapeAttribute(image.alt || `image ${index + 1}`)}" style="--lic-offset: ${index * 5}px">
    `).join("");
    return `
      <div class="lic-stack" title="双击展开这一行">
        ${preview}
        <span class="lic-count">${batch.images.length}</span>
      </div>
    `;
  }

  function renderStatus() {
    const totalImages = state.batches.reduce((sum, batch) => sum + batch.images.length, 0);
    const selectedCount = state.batches.reduce((sum, batch) => sum + batch.selected.size, 0);
    status.textContent = state.batches.length
      ? `${state.status} · 暂存 ${state.batches.length} 行 / ${totalImages} 张 · 已选 ${selectedCount} 张`
      : state.status;
  }

  function downloadSelected(batch) {
    const images = batch.images.filter(image => batch.selected.has(image.id));
    if (images.length === 0) {
      state.status = "请先选择要保存的图片";
      renderStatus();
      return;
    }

    chrome.runtime.sendMessage(
      {
        type: "downloadImages",
        folder: folderName(batch),
        images
      },
      response => {
        if (chrome.runtime.lastError) {
          state.status = `保存失败：${chrome.runtime.lastError.message}`;
        } else if (response?.ok) {
          state.status = `已开始保存 ${batch.title} 的 ${response.started} 张图片`;
        } else {
          state.status = response?.error || "保存失败";
        }
        renderStatus();
      }
    );
  }

  function batchForButton(button) {
    const id = button.closest(".lic-batch")?.dataset?.batchId;
    return state.batches.find(batch => batch.id === id);
  }

  function collectImages() {
    const scope = findBestImageScope();
    const found = [];
    const seen = new Set();

    for (const img of scope.element.querySelectorAll("img, picture img")) {
      const url = normalizeURL(img.currentSrc || img.src);
      if (!url || seen.has(url)) continue;
      const width = img.naturalWidth || img.width || 0;
      const height = img.naturalHeight || img.height || 0;
      if (!looksUsefulImage(url, width, height)) continue;
      seen.add(url);
      found.push(toImageRecord(url, img.alt, width, height, img.getBoundingClientRect()));
    }

    for (const element of scope.element.querySelectorAll("*")) {
      const style = getComputedStyle(element);
      for (const url of extractBackgroundURLs(style.backgroundImage)) {
        const normalized = normalizeURL(url);
        if (!normalized || seen.has(normalized)) continue;
        const rect = element.getBoundingClientRect();
        if (!looksUsefulImage(normalized, rect.width, rect.height)) continue;
        seen.add(normalized);
        found.push(toImageRecord(normalized, element.getAttribute("aria-label") || "", rect.width, rect.height, rect));
      }
    }

    const images = found
      .filter(image => isInsideReadableArea(scope.element, image.sourceRect))
      .map(({ sourceRect, ...image }) => image)
      .slice(0, 80);

    return {
      images,
      sourceLabel: scope.label
    };
  }

  function toImageRecord(url, alt, width, height, sourceRect) {
    const id = stableID(url);
    return {
      id,
      url,
      alt: alt || "",
      label: imageLabel(url, width, height),
      name: imageName(url, id),
      type: typeFromURL(url),
      sourceRect
    };
  }

  function findBestImageScope() {
    const candidates = [];
    for (const selector of POST_SELECTORS) {
      for (const element of document.querySelectorAll(selector)) {
        if (element === root || root.contains(element)) continue;
        const score = imageScopeScore(element);
        if (score > 0) {
          candidates.push({ element, score, label: scopeLabelFor(selector) });
        }
      }
    }

    if (candidates.length > 0) {
      candidates.sort((a, b) => b.score - a.score);
      return candidates[0];
    }

    return {
      element: document.body || document.documentElement,
      label: "页面"
    };
  }

  function imageScopeScore(element) {
    const rect = element.getBoundingClientRect();
    if (rect.width < 240 || rect.height < 180) return 0;
    const viewportOverlap = overlapArea(rect, {
      left: 0,
      top: 0,
      right: window.innerWidth,
      bottom: window.innerHeight,
      width: window.innerWidth,
      height: window.innerHeight
    });
    const visibleBonus = viewportOverlap > 0 ? 1000 : 0;
    const imageCount = [...element.querySelectorAll("img")]
      .filter(img => looksUsefulImage(normalizeURL(img.currentSrc || img.src), img.naturalWidth || img.width || 0, img.naturalHeight || img.height || 0))
      .length;
    const textLength = (element.innerText || "").trim().length;
    const area = Math.min(rect.width * rect.height, 1_200_000);
    const className = String(element.className || "");
    const postClassBonus = /note|post|media|swiper|article/i.test(className) ? 800 : 0;
    return visibleBonus + postClassBonus + imageCount * 250 + Math.min(textLength, 3000) * 0.08 + area / 3000;
  }

  function scopeLabelFor(selector) {
    if (selector.includes("dialog")) return "当前弹窗";
    if (selector.includes("article") || selector === "article") return "当前文章";
    if (selector === "main") return "主内容区";
    return "当前帖子";
  }

  function overlapArea(a, b) {
    const x = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
    const y = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
    return x * y;
  }

  function isInsideReadableArea(scopeElement, rect) {
    if (!rect) return true;
    const scopeRect = scopeElement.getBoundingClientRect();
    if (scopeElement === document.body || scopeElement === document.documentElement) return true;
    return overlapArea(scopeRect, rect) > 0;
  }

  function looksUsefulImage(url, width, height) {
    if (!/^https?:\/\//i.test(url) && !/^data:image\//i.test(url)) return false;
    if (/sprite|avatar|icon|logo|emoji|badge/i.test(url) && Math.max(width, height) < 300) return false;
    if (width === 0 || height === 0) return true;
    return Math.max(width, height) >= MIN_IMAGE_EDGE;
  }

  function normalizeURL(value) {
    if (!value || value.startsWith("blob:")) return "";
    try {
      return new URL(value, location.href).href;
    } catch {
      return "";
    }
  }

  function extractBackgroundURLs(backgroundImage) {
    if (!backgroundImage || backgroundImage === "none") return [];
    return [...backgroundImage.matchAll(/url\((['"]?)(.*?)\1\)/g)].map(match => match[2]);
  }

  function imageLabel(url, width, height) {
    const size = width && height ? `${Math.round(width)}x${Math.round(height)}` : "image";
    const name = imageName(url, "");
    return `${name || "image"} · ${size}`;
  }

  function imageName(url, fallback) {
    try {
      const path = new URL(url).pathname.split("/").filter(Boolean).pop() || fallback || "image";
      return decodeURIComponent(path).replace(/\.[a-z0-9]{2,5}$/i, "").slice(0, 40) || "image";
    } catch {
      return fallback || "image";
    }
  }

  function typeFromURL(url) {
    if (url.startsWith("data:")) return url.slice(5, url.indexOf(";"));
    return "";
  }

  function stableID(url) {
    let hash = 0;
    for (let index = 0; index < url.length; index += 1) {
      hash = ((hash << 5) - hash + url.charCodeAt(index)) | 0;
    }
    return `img-${Math.abs(hash)}`;
  }

  function folderName(batch) {
    const host = location.hostname.replace(/^www\./, "") || "page";
    const date = new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-");
    const label = sanitizePathSegment(batch?.title || "images");
    return `LingganImages/${host}-${date}-${label}`;
  }

  function sanitizePathSegment(value) {
    return String(value || "images")
      .replace(/[\\/:*?"<>|]+/g, "-")
      .replace(/\s+/g, "-")
      .slice(0, 40) || "images";
  }

  function escapeHTML(value) {
    return String(value).replace(/[&<>"']/g, char => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    }[char]));
  }

  function escapeAttribute(value) {
    return escapeHTML(value);
  }
})();
