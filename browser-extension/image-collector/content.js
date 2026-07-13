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
    images: [],
    expanded: false,
    selected: new Set(),
    status: "",
    sourceLabel: ""
  };

  if (document.getElementById(ROOT_ID)) {
    return;
  }

  const root = document.createElement("div");
  root.id = ROOT_ID;
  root.innerHTML = `
    <button class="lic-trigger" type="button" title="灵感收图：点击打开，Cmd+点击直接收当前帖子图片" aria-label="灵感收图">
      <span class="lic-bubble-mark">✦</span>
    </button>
    <section class="lic-panel lic-hidden" aria-label="灵感图片采集器">
      <div class="lic-header">
        <div>
          <div class="lic-title">灵感图片格</div>
          <div class="lic-subtitle">Cmd+点泡泡直接收当前帖子</div>
        </div>
        <div class="lic-actions">
          <button class="lic-small" type="button" data-action="refresh">刷新</button>
          <button class="lic-small" type="button" data-action="collapse">收起</button>
        </div>
      </div>
      <div class="lic-stack" title="双击展开图片格"></div>
      <div class="lic-toolbar lic-hidden">
        <button class="lic-small" type="button" data-action="select-all">全选</button>
        <button class="lic-small" type="button" data-action="clear">取消</button>
        <button class="lic-primary" type="button" data-action="download">保存选中</button>
      </div>
      <div class="lic-grid lic-hidden"></div>
      <div class="lic-status"></div>
    </section>
  `;
  (document.body || document.documentElement).appendChild(root);

  const trigger = root.querySelector(".lic-trigger");
  const panel = root.querySelector(".lic-panel");
  const stack = root.querySelector(".lic-stack");
  const grid = root.querySelector(".lic-grid");
  const toolbar = root.querySelector(".lic-toolbar");
  const status = root.querySelector(".lic-status");

  trigger.addEventListener("click", event => {
    collectAndRender();
    if (event.metaKey) {
      state.expanded = true;
      render();
    }
    panel.classList.remove("lic-hidden");
  });

  stack.addEventListener("dblclick", () => {
    state.expanded = !state.expanded;
    render();
  });

  panel.addEventListener("click", event => {
    const button = event.target?.closest?.("button[data-action]");
    const action = button?.dataset?.action;
    if (!action) return;
    event.preventDefault();
    event.stopPropagation();

    if (action === "refresh") {
      collectAndRender();
    } else if (action === "collapse") {
      state.expanded = false;
      panel.classList.add("lic-hidden");
      render();
    } else if (action === "select-all") {
      state.images.forEach(image => state.selected.add(image.id));
      render();
    } else if (action === "clear") {
      state.selected.clear();
      render();
    } else if (action === "download") {
      downloadSelected();
    }
  });

  grid.addEventListener("change", event => {
    if (!event.target?.matches("input[type='checkbox']")) return;
    const id = event.target.value;
    if (event.target.checked) {
      state.selected.add(id);
    } else {
      state.selected.delete(id);
    }
    renderStatus();
  });

  function collectAndRender() {
    const result = collectImages();
    state.images = result.images;
    state.sourceLabel = result.sourceLabel;
    state.selected = new Set(state.images.map(image => image.id));
    state.expanded = false;
    state.status = state.images.length
      ? `已从${state.sourceLabel}收集 ${state.images.length} 张候选图片`
      : "没有找到适合保存的大图";
    render();
  }

  function render() {
    renderStack();
    renderGrid();
    renderStatus();
  }

  function renderStack() {
    const previewImages = state.images.slice(0, 4);
    stack.innerHTML = "";
    stack.classList.toggle("lic-empty", state.images.length === 0);

    if (state.images.length === 0) {
      stack.innerHTML = `
        <div class="lic-empty-text">未收集到图片</div>
      `;
      return;
    }

    const label = document.createElement("div");
    label.className = "lic-count";
    label.textContent = `${state.images.length} 张`;
    stack.appendChild(label);

    previewImages.forEach((image, index) => {
      const img = document.createElement("img");
      img.src = image.url;
      img.alt = image.alt || `image ${index + 1}`;
      img.style.setProperty("--lic-offset", `${index * 8}px`);
      stack.appendChild(img);
    });
  }

  function renderGrid() {
    const expanded = state.expanded && state.images.length > 0;
    grid.classList.toggle("lic-hidden", !expanded);
    toolbar.classList.toggle("lic-hidden", !expanded);

    if (!expanded) {
      grid.innerHTML = "";
      return;
    }

    grid.innerHTML = "";
    for (const image of state.images) {
      const item = document.createElement("label");
      item.className = "lic-item";
      item.innerHTML = `
        <input type="checkbox" value="${escapeAttribute(image.id)}" ${state.selected.has(image.id) ? "checked" : ""}>
        <img src="${escapeAttribute(image.url)}" alt="${escapeAttribute(image.alt || "collected image")}">
        <span>${escapeHTML(image.label)}</span>
      `;
      grid.appendChild(item);
    }
  }

  function renderStatus() {
    const selectedCount = state.selected.size;
    status.textContent = state.images.length
      ? `${state.status} · 已选 ${selectedCount} 张`
      : state.status;
  }

  function downloadSelected() {
    const images = state.images.filter(image => state.selected.has(image.id));
    if (images.length === 0) {
      state.status = "请先选择要保存的图片";
      renderStatus();
      return;
    }

    chrome.runtime.sendMessage(
      {
        type: "downloadImages",
        folder: folderName(),
        images
      },
      response => {
        if (chrome.runtime.lastError) {
          state.status = `保存失败：${chrome.runtime.lastError.message}`;
        } else if (response?.ok) {
          state.status = `已开始保存 ${response.started} 张图片`;
        } else {
          state.status = response?.error || "保存失败";
        }
        renderStatus();
      }
    );
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

  function folderName() {
    const host = location.hostname.replace(/^www\./, "") || "page";
    const date = new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-");
    return `LingganImages/${host}-${date}`;
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
