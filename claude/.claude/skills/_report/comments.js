(() => {
  if (!window.showDirectoryPicker) return;
  const style = document.createElement("style");
  style.textContent = `
:root { --cm-line: #d0d7de; --cm-bg: #f3f4f6; --cm-fg: #1f2328; --cm-muted: #656d76; --cm-accent: #0969da; --cm-input: #ffffff; }
@media (prefers-color-scheme: dark) {
  :root { --cm-line: #30363d; --cm-bg: #161b22; --cm-fg: #e6edf3; --cm-muted: #8d96a0; --cm-accent: #58a6ff; --cm-input: #0d1117; }
}
.cm-add { margin-left: 8px; padding: 0 6px; border: 0; border-radius: 4px; background: none;
  color: var(--cm-muted); font: inherit; font-size: 13px; cursor: pointer; opacity: 0; }
.cm-on :is(li, tr, h1, h2, h3, h4, p, pre, figure, .dl):hover .cm-add, .cm-add.has { opacity: 1; }
.cm-box { margin: 8px 0; padding: 8px 12px; border: 1px solid var(--cm-line); border-radius: 6px;
  background: var(--cm-bg); color: var(--cm-fg); font-size: 14px; font-weight: 400; }
.cm-box[hidden] { display: none; }
.cm-item { margin: 4px 0; padding-left: 8px; border-left: 3px solid var(--cm-accent); white-space: pre-wrap; }
.cm-item.done { opacity: .5; border-left-color: var(--cm-muted); }
.cm-box textarea { width: 100%; min-height: 64px; margin-top: 4px; padding: 6px 8px; border: 1px solid var(--cm-line);
  border-radius: 4px; background: var(--cm-input); color: var(--cm-fg); font: inherit; }
.cm-box button, .cm-enable { padding: 2px 12px; border: 1px solid var(--cm-line); border-radius: 6px;
  background: var(--cm-bg); color: var(--cm-fg); font: inherit; font-size: 13px; cursor: pointer; }
.cm-enable { position: fixed; top: 12px; right: 16px; z-index: 10; }
`;
  document.head.append(style);
  const FILE = "comments.jsonc";
  const doc = decodeURIComponent(location.pathname.split("/").pop());
  const ROOT_KEY = "root";
  const text = (n) => n.textContent.replace(/\s+/g, " ").trim().slice(0, 80);
  const TARGETS = "li, tbody tr, h1, h2, h3, h4, p, pre, figure, .dl";
  const items = [...document.querySelectorAll(TARGETS)]
    .filter((node) => !node.querySelector(TARGETS))
    .map((node) => ({ node, quote: node.dataset.quote || text(node) }));
  let dir = null;
  let comments = [];

  const idb = (mode, fn) => new Promise((resolve, reject) => {
    const open = indexedDB.open("report-comments", 1);
    open.onupgradeneeded = () => open.result.createObjectStore("kv");
    open.onerror = () => reject(open.error);
    open.onsuccess = () => {
      const req = fn(open.result.transaction("kv", mode).objectStore("kv"));
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    };
  });

  async function read() {
    let file;
    try {
      file = await (await dir.getFileHandle(FILE)).getFile();
    } catch (e) {
      if (e.name === "NotFoundError") return { comments: [] };
      throw e;
    }
    const body = await file.text();
    return body.trim() ? JSON.parse(body) : { comments: [] };
  }

  async function add(item, body) {
    const data = await read();
    data.comments.push({
      file: doc, quote: item.quote, text: body, status: "open", created: new Date().toISOString(),
    });
    const w = await (await dir.getFileHandle(FILE, { create: true })).createWritable();
    await w.write(JSON.stringify(data, null, 2) + "\n");
    await w.close();
    comments = data.comments;
  }

  function mine(item) {
    return comments.filter((c) => c.file === doc && c.quote === item.quote);
  }

  function draw(item) {
    const list = mine(item);
    item.button.textContent = list.length ? `💬 ${list.length}` : "💬";
    item.button.classList.toggle("has", list.length > 0);
    item.box.replaceChildren(
      ...list.map((c) => Object.assign(document.createElement("div"), {
        className: `cm-item${c.status === "open" ? "" : " done"}`, textContent: c.text,
      })),
    );
    const area = document.createElement("textarea");
    area.placeholder = "コメント";
    const save = Object.assign(document.createElement("button"), { textContent: "保存" });
    save.addEventListener("click", async () => {
      const body = area.value.trim();
      if (!body) return;
      try {
        await add(item, body);
      } catch (e) {
        alert(`${FILE} に書き込めませんでした: ${e.message}`);
        return;
      }
      items.forEach(draw);
      show(item, true);
    });
    item.box.append(area, save);
  }

  function show(item, visible) {
    item.box.hidden = !visible;
    if (item.row) item.row.hidden = !visible;
  }

  function mount() {
    document.body.classList.add("cm-on");
    for (const item of items) {
      item.button = Object.assign(document.createElement("button"), { className: "cm-add", textContent: "💬" });
      item.box = Object.assign(document.createElement("div"), { className: "cm-box", hidden: true });
      item.button.addEventListener("click", () => show(item, item.box.hidden));
      const isRow = item.node.tagName === "TR";
      (isRow ? item.node.lastElementChild : item.node).append(item.button);
      if (isRow) {
        const cell = Object.assign(document.createElement("td"), { colSpan: item.node.children.length });
        cell.append(item.box);
        item.row = Object.assign(document.createElement("tr"), { hidden: true });
        item.row.append(cell);
        item.node.after(item.row);
      } else if (item.node.tagName === "LI") {
        item.node.append(item.box);
      } else {
        item.node.after(item.box);
      }
    }
    items.forEach(draw);
  }

  const feature = decodeURIComponent(location.pathname.split("/").slice(-2, -1)[0] || "");

  async function resolve(picked) {
    try {
      await picked.getFileHandle(doc);
      return picked;
    } catch {
      return picked.getDirectoryHandle(feature);
    }
  }

  async function use(picked) {
    dir = await resolve(picked);
    await dir.getFileHandle(doc);
    comments = (await read()).comments;
    mount();
    enable.remove();
  }

  const enable = Object.assign(document.createElement("button"), { className: "cm-enable", textContent: "コメントを有効にする" });
  enable.addEventListener("click", async () => {
    try {
      const saved = await idb("readonly", (s) => s.get(ROOT_KEY)).catch(() => null);
      let picked = null;
      if (saved && (await saved.requestPermission({ mode: "readwrite" })) === "granted") {
        try {
          await use(saved);
          picked = saved;
        } catch {}
      }
      if (!picked) {
        picked = await showDirectoryPicker({ id: "specs-comments", mode: "readwrite", ...(saved ? { startIn: saved } : {}) });
        await use(picked);
      }
      idb("readwrite", (s) => s.put(picked, ROOT_KEY)).catch(() => {});
    } catch (e) {
      if (e.name !== "AbortError") alert(`.specs か、このページがあるフォルダを選んでください: ${e.message}`);
    }
  });
  document.body.append(enable);

  idb("readonly", (s) => s.get(ROOT_KEY)).then(async (saved) => {
    if (saved && (await saved.queryPermission({ mode: "readwrite" })) === "granted") await use(saved);
  }).catch(() => {});
})();
