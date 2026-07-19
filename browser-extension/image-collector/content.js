(() => {
  const ROOT_ID = "linggan-image-collector-root";
  const INSTANCE_KEY = "__lingganImageCollectorInstance";
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
  const runtime = globalThis.chrome?.runtime;
  if (!runtime?.onMessage) {
    return;
  }

  const existingInstance = globalThis[INSTANCE_KEY];
  if (existingInstance && document.getElementById(ROOT_ID)) {
    return;
  }
  existingInstance?.dispose?.();
  document.getElementById(ROOT_ID)?.remove();

  const state = {
    batches: [],
    activeBatchID: "",
    status: "",
    autoHideTrigger: false,
    captureInProgress: false
  };

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
          <button class="lic-small" type="button" data-action="archive-page" title="保存 HTML 与完整网页截图">存网页</button>
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
  const header = root.querySelector(".lic-header");

  const messageListener = (message, _sender, sendResponse) => {
    if (message?.type === "captureCurrentPost") {
      setPanelVisible(true);
      void captureBatch(message.pageData);
      sendResponse({ ok: true });
      return false;
    }
    if (message?.type === "hideCollectorPanel") {
      setPanelVisible(false);
      sendResponse({ ok: true });
      return false;
    }
    if (message?.type === "preparePageArchive") {
      void preparePageArchive()
        .then(result => sendResponse(result))
        .catch(error => sendResponse({ ok: false, error: error?.message || String(error) }));
      return true;
    }
    if (message?.type === "serializePageHTML") {
      try {
        sendResponse({ ok: true, ...serializePageHTML() });
      } catch (error) {
        sendResponse({ ok: false, error: error?.message || String(error) });
      }
      return false;
    }
    if (message?.type === "restorePageArchive") {
      restorePageArchive();
      sendResponse({ ok: true });
      return false;
    }
    return false;
  };
  runtime.onMessage.addListener(messageListener);

  const keydownListener = event => {
    if (event.ctrlKey && event.shiftKey && event.key.toLowerCase() === "l") {
      event.preventDefault();
      setPanelVisible(true);
      void captureBatch();
    }
  };
  window.addEventListener("keydown", keydownListener);

  globalThis[INSTANCE_KEY] = {
    dispose() {
      window.removeEventListener("keydown", keydownListener);
      try {
        runtime.onMessage.removeListener(messageListener);
      } catch {
        // The previous extension context may already be invalidated.
      }
      root.remove();
    }
  };

  let panelDrag;
  header.addEventListener("pointerdown", event => {
    if (event.target.closest("button")) return;
    const rect = panel.getBoundingClientRect();
    panelDrag = {
      pointerID: event.pointerId,
      offsetX: event.clientX - rect.left,
      offsetY: event.clientY - rect.top
    };
    panel.style.right = "auto";
    panel.style.left = `${rect.left}px`;
    panel.style.top = `${rect.top}px`;
    header.setPointerCapture(event.pointerId);
    header.classList.add("lic-dragging");
    event.preventDefault();
  });

  header.addEventListener("pointermove", event => {
    if (!panelDrag || panelDrag.pointerID !== event.pointerId) return;
    const maxLeft = Math.max(8, window.innerWidth - panel.offsetWidth - 8);
    const maxTop = Math.max(8, window.innerHeight - Math.min(panel.offsetHeight, window.innerHeight - 16) - 8);
    const left = Math.min(Math.max(event.clientX - panelDrag.offsetX, 8), maxLeft);
    const top = Math.min(Math.max(event.clientY - panelDrag.offsetY, 8), maxTop);
    panel.style.left = `${left}px`;
    panel.style.top = `${top}px`;
  });

  const finishPanelDrag = event => {
    if (!panelDrag || panelDrag.pointerID !== event.pointerId) return;
    panelDrag = null;
    header.classList.remove("lic-dragging");
    if (header.hasPointerCapture(event.pointerId)) {
      header.releasePointerCapture(event.pointerId);
    }
  };
  header.addEventListener("pointerup", finishPanelDrag);
  header.addEventListener("pointercancel", finishPanelDrag);

  trigger.addEventListener("click", event => {
    setPanelVisible(true);
    void captureBatch();
  });

  batches.addEventListener("dblclick", event => {
    if (event.target?.closest?.("button, input, .lic-item")) return;
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
      void captureBatch();
    } else if (action === "archive-page") {
      archiveCurrentPage();
    } else if (action === "close") {
      setPanelVisible(false);
    } else if (action === "select-all") {
      const batch = batchForButton(button);
      batch?.images.forEach(image => batch.selected.add(image.id));
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

  panel.addEventListener("dblclick", event => {
    const button = event.target?.closest?.("button[data-action='select-all']");
    if (!button) return;
    event.preventDefault();
    event.stopPropagation();
    batchForButton(button)?.selected.clear();
    render();
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
    event.target.closest(".lic-item")?.classList.toggle("lic-item-selected", event.target.checked);
    renderStatus();
  });

  async function captureBatch(pageData = null) {
    if (state.captureInProgress) return;
    state.captureInProgress = true;
    state.status = "正在读取当前帖子的完整图片…";
    renderStatus();
    try {
      await prepareLazyImages();
      const result = collectImages(pageData);
      const batch = {
        id: `batch-${Date.now()}-${Math.random().toString(16).slice(2)}`,
        title: result.title,
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
    } catch (error) {
      state.status = `收图失败：${error?.message || String(error)}`;
    } finally {
      state.captureInProgress = false;
      render();
    }
  }

  function setPanelVisible(visible) {
    panel.classList.toggle("lic-hidden", !visible);
    runtime.sendMessage({ type: "collectorPanelState", open: visible }, () => {
      void runtime.lastError;
    });
  }

  function archiveCurrentPage() {
    state.status = "正在保存 HTML 与完整网页截图…";
    renderStatus();
    runtime.sendMessage({ type: "archiveCurrentPage" }, response => {
      if (runtime.lastError) {
        state.status = `网页保存失败：${runtime.lastError.message}`;
      } else if (response?.ok) {
        state.status = response.message || "已保存 HTML 与完整网页截图";
      } else {
        state.status = response?.error || "网页保存失败";
      }
      renderStatus();
    });
  }

  let archiveScrollPosition;

  async function preparePageArchive() {
    archiveScrollPosition = { x: window.scrollX, y: window.scrollY };
    root.style.visibility = "hidden";
    await prepareLazyImages(document);

    const scrollHeight = Math.max(document.documentElement.scrollHeight, document.body?.scrollHeight || 0);
    const maxScroll = Math.max(0, scrollHeight - window.innerHeight);
    const sampleCount = Math.min(20, Math.max(1, Math.ceil(scrollHeight / Math.max(window.innerHeight, 1))));
    for (let index = 0; index < sampleCount; index += 1) {
      const y = sampleCount === 1 ? 0 : Math.round(maxScroll * index / (sampleCount - 1));
      window.scrollTo(archiveScrollPosition.x, y);
      await new Promise(resolve => window.setTimeout(resolve, 90));
    }
    window.scrollTo(archiveScrollPosition.x, archiveScrollPosition.y);
    await new Promise(resolve => window.setTimeout(resolve, 180));
    return { ok: true, title: document.title, url: location.href };
  }

  function restorePageArchive() {
    root.style.visibility = "";
    if (archiveScrollPosition) {
      window.scrollTo(archiveScrollPosition.x, archiveScrollPosition.y);
      archiveScrollPosition = undefined;
    }
  }

  function serializePageHTML() {
    const clone = document.documentElement.cloneNode(true);
    clone.querySelector(`#${ROOT_ID}`)?.remove();
    clone.querySelectorAll("script, meta[http-equiv='Content-Security-Policy']").forEach(element => element.remove());
    clone.querySelectorAll("input").forEach(input => {
      input.removeAttribute("value");
      input.removeAttribute("checked");
    });
    clone.querySelectorAll("textarea").forEach(textarea => {
      textarea.textContent = "";
    });
    const head = clone.querySelector("head") || clone.insertBefore(document.createElement("head"), clone.firstChild);
    const base = document.createElement("base");
    base.href = location.href;
    head.prepend(base);
    const source = document.createElement("meta");
    source.name = "linggan-source-url";
    source.content = location.href;
    head.prepend(source);
    return {
      title: document.title,
      url: location.href,
      html: `<!doctype html>\n${clone.outerHTML}`
    };
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
          <button class="lic-small" type="button" data-action="select-all" title="单击全选，双击取消全选">全选</button>
          <button class="lic-small" type="button" data-action="remove-batch">移除</button>
          <button class="lic-primary" type="button" data-action="download">保存选中</button>
        </div>
        <div class="lic-grid${expanded ? "" : " lic-hidden"}">
          ${batch.images.map(image => `
            <label class="lic-item${batch.selected.has(image.id) ? " lic-item-selected" : ""}">
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
        title: batch.title,
        images
      },
      response => {
        if (chrome.runtime.lastError) {
          state.status = `保存失败：${chrome.runtime.lastError.message}`;
        } else if (response?.ok) {
          state.status = `已保存 ${batch.title} 的 ${response.saved} 张 PNG${response.duplicates ? `，自动跳过 ${response.duplicates} 张重复图` : ""}${response.failed ? `，${response.failed} 张失败` : ""}`;
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

  function collectImages(pageData = null) {
    const structured = structuredPostResult(pageData);
    if (structured) return structured;

    const postScope = findBestImageScope();
    const scope = findBestMediaScope(postScope.element);
    const found = [];
    const seen = new Set();

    for (const img of scope.element.querySelectorAll("img, picture img")) {
      const url = bestImageURLFor(img);
      const identity = canonicalImageKey(url);
      if (!url || seen.has(identity)) continue;
      const width = img.naturalWidth || img.width || 0;
      const height = img.naturalHeight || img.height || 0;
      if (!looksUsefulImage(url, width, height, imageElementContext(img))) continue;
      seen.add(identity);
      found.push(toImageRecord(url, img.alt, width, height, img.getBoundingClientRect()));
    }

    for (const element of scope.element.querySelectorAll("*")) {
      const style = getComputedStyle(element);
      for (const url of extractBackgroundURLs(style.backgroundImage)) {
        const normalized = normalizeURL(url);
        const identity = canonicalImageKey(normalized);
        if (!normalized || seen.has(identity)) continue;
        const rect = element.getBoundingClientRect();
        if (!looksUsefulImage(normalized, rect.width, rect.height, imageElementContext(element))) continue;
        seen.add(identity);
        found.push(toImageRecord(normalized, element.getAttribute("aria-label") || "", rect.width, rect.height, rect));
      }
    }

    const images = found
      .filter(image => isInsideReadableArea(scope.element, image.sourceRect))
      .map(({ sourceRect, ...image }) => image)
      .slice(0, 80);

    return {
      images,
      sourceLabel: postScope.label,
      title: extractPostTitle(postScope.element)
    };
  }

  function structuredPostResult(pageData) {
    if (!Array.isArray(pageData?.images) || pageData.images.length === 0) return null;
    const seen = new Set();
    const images = [];
    for (const image of pageData.images) {
      const urls = [...new Set([...(Array.isArray(image.urls) ? image.urls : []), image.url]
        .map(normalizeURL)
        .filter(Boolean))];
      const url = urls[0];
      const identity = canonicalImageKey(url);
      if (!url || seen.has(identity)) continue;
      seen.add(identity);
      images.push(toImageRecord(
        url,
        image.alt || "",
        Number(image.width || 0),
        Number(image.height || 0),
        null,
        urls
      ));
    }
    return {
      images,
      sourceLabel: "当前帖子",
      title: cleanTitle(pageData.title) || extractPostTitle(document.body)
    };
  }

  async function prepareLazyImages(scope = findBestImageScope().element) {
    for (const img of scope.querySelectorAll("img")) {
      img.loading = "eager";
      const lazyURL = ["data-original", "data-src", "data-lazy-src", "data-actualsrc"]
        .map(name => img.getAttribute(name))
        .find(Boolean);
      if (lazyURL && (!img.getAttribute("src") || img.naturalWidth === 0)) {
        img.src = lazyURL;
      }
    }
    await new Promise(resolve => window.setTimeout(resolve, 650));
  }

  function toImageRecord(url, alt, width, height, sourceRect, urls = [url]) {
    const id = stableID(url);
    return {
      id,
      url,
      urls,
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

  function findBestMediaScope(postElement) {
    const selectors = [
      "[class*='swiper-wrapper']",
      "[class*='swiper']",
      "[class*='carousel']",
      "[class*='slider']",
      "[class*='gallery']",
      "[class*='image-list']",
      "[class*='image-container']",
      "[class*='media-container']"
    ];
    const candidates = [];
    for (const selector of selectors) {
      candidates.push(...postElement.querySelectorAll(selector));
    }

    const scored = candidates.map(element => {
      const images = [...element.querySelectorAll("img")]
        .map(img => ({ img, url: bestImageURLFor(img) }))
        .filter(item => item.url && looksUsefulImage(
          item.url,
          item.img.naturalWidth || item.img.width || 0,
          item.img.naturalHeight || item.img.height || 0,
          imageElementContext(item.img)
        ));
      const uniqueCount = new Set(images.map(item => canonicalImageKey(item.url))).size;
      const className = String(element.className || "");
      const mediaBonus = /swiper-wrapper|carousel|slider|gallery|image-list|media-container/i.test(className) ? 6_000 : 0;
      return { element, score: uniqueCount * 10_000 + mediaBonus };
    }).filter(candidate => candidate.score > 0);

    scored.sort((a, b) => b.score - a.score);
    return scored[0] || { element: postElement };
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
      .filter(img => looksUsefulImage(
        normalizeURL(img.currentSrc || img.src),
        img.naturalWidth || img.width || 0,
        img.naturalHeight || img.height || 0,
        imageElementContext(img)
      ))
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

  function looksUsefulImage(url, width, height, context = "") {
    if (!/^https?:\/\//i.test(url) && !/^data:image\//i.test(url)) return false;
    const hints = `${url} ${context}`.toLowerCase();
    if (/avatar|head.?portrait|profile.?photo|user.?icon|emoji|emoticon|sticker|expression|comment.?icon|badge|logo|sprite/.test(hints)) {
      return false;
    }
    if (width === 0 || height === 0) return true;
    const longestEdge = Math.max(width, height);
    const shortestEdge = Math.min(width, height);
    const ratio = longestEdge / Math.max(shortestEdge, 1);
    if (longestEdge <= 320 && ratio <= 1.35) return false;
    return longestEdge >= MIN_IMAGE_EDGE;
  }

  function imageElementContext(element) {
    const values = [];
    let current = element;
    for (let depth = 0; current && depth < 5; depth += 1, current = current.parentElement) {
      values.push(
        current.getAttribute?.("alt") || "",
        current.getAttribute?.("aria-label") || "",
        current.getAttribute?.("role") || "",
        current.id || "",
        typeof current.className === "string" ? current.className : ""
      );
    }
    return values.join(" ");
  }

  function normalizeURL(value) {
    if (!value || value.startsWith("blob:")) return "";
    try {
      return new URL(value, location.href).href;
    } catch {
      return "";
    }
  }

  function bestImageURLFor(img) {
    const candidates = [];
    const push = (value, priority = 0) => {
      const url = normalizeURL(value);
      if (url) candidates.push({ url, priority });
    };
    push(img.getAttribute?.("data-original"), 50_000);
    push(img.getAttribute?.("data-origin-src"), 45_000);
    push(img.getAttribute?.("data-actualsrc"), 40_000);
    push(img.getAttribute?.("data-lazy-src"), 35_000);
    push(img.getAttribute?.("data-src"), 30_000);
    push(img.currentSrc, 20_000);
    push(img.src, 10_000);

    const srcsets = [img.getAttribute?.("srcset"), img.parentElement?.querySelector?.("source[srcset]")?.getAttribute("srcset")];
    for (const srcset of srcsets.filter(Boolean)) {
      for (const entry of srcset.split(",")) {
        const [value, descriptor = ""] = entry.trim().split(/\s+/, 2);
        const size = Number.parseFloat(descriptor) || 1;
        push(value, 25_000 + size);
      }
    }
    candidates.sort((a, b) => b.priority - a.priority);
    return candidates[0]?.url || "";
  }

  function canonicalImageKey(value) {
    const normalized = normalizeURL(value);
    if (!normalized) return "";
    try {
      const url = new URL(normalized);
      url.hash = "";
      for (const key of [...url.searchParams.keys()]) {
        if (/^(w|h|width|height|quality|format|resize|crop|imageView2|imageMogr2|x-oss-process|thumbnail)$/i.test(key)) {
          url.searchParams.delete(key);
        }
      }
      url.pathname = url.pathname.replace(/!.+$/, "");
      if (/xhscdn\.com$|xiaohongshu\.com$/i.test(url.hostname)) {
        return url.pathname;
      }
      return url.href;
    } catch {
      return normalized;
    }
  }

  function extractPostTitle(scopeElement) {
    const container = scopeElement.closest?.("[role='dialog'], article, main, [class*='note-detail'], [class*='post-detail']") || scopeElement;
    const selectors = [
      "h1",
      "h2",
      "[class~='title']",
      "[class*='note-title']",
      "[class*='post-title']"
    ];
    for (const selector of selectors) {
      for (const element of container.querySelectorAll(selector)) {
        const title = cleanTitle(element.textContent);
        if (title) return title;
      }
    }
    const metadata = [
      document.querySelector("meta[property='og:title']")?.content,
      document.querySelector("meta[name='twitter:title']")?.content,
      document.title
    ];
    return metadata.map(cleanTitle).find(Boolean) || `当前帖子 ${new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`;
  }

  function cleanTitle(value) {
    const title = String(value || "").replace(/\s+/g, " ").trim();
    if (title.length < 2) return "";
    return title.slice(0, 100);
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
