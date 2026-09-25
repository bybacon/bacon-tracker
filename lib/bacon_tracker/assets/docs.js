// Docs column browser (BT-139). Finder-style: one column per selected folder,
// the rendered page pinned right. Deep nesting pushes columns left - no tree,
// no breadcrumbs, by design (§13.2).
(function () {
  const API_BASE = window.BT_API_BASE || '';
  const columnsEl = document.getElementById('doc-columns');
  const previewEl = document.getElementById('doc-preview');
  let tree = [];
  let selection = []; // node per depth

  function nodesAt(depth) {
    let nodes = tree;
    for (let i = 0; i < depth; i++) nodes = selection[i].children || [];
    return nodes;
  }

  function render() {
    columnsEl.textContent = '';
    for (let depth = 0; depth <= selection.length; depth++) {
      const nodes = nodesAt(depth);
      if (depth > 0 && selection[depth - 1].type !== 'dir') break;
      if (!nodes.length) break;
      const col = document.createElement('ul');
      col.className = 'doc-col';
      nodes.forEach((node) => {
        const li = document.createElement('li');
        li.textContent = (node.type === 'dir' ? '▸ ' : '') + node.name;
        li.className = 'doc-entry doc-' + node.type;
        if (selection[depth] === node) li.classList.add('selected');
        li.addEventListener('click', () => select(depth, node));
        col.appendChild(li);
      });
      columnsEl.appendChild(col);
    }
    columnsEl.scrollLeft = columnsEl.scrollWidth; // keep the preview visible
  }

  async function select(depth, node) {
    if (node.decisions) {
      // A tracked subtree has a board; the browser hands over rather than
      // column-walking the records (BT-176).
      window.location = (API_BASE || '') + '/docs/decisions';
      return;
    }
    selection = selection.slice(0, depth);
    selection.push(node);
    render();
    if (node.type === 'page') await showPage(node.path, node.name);
  }

  let currentPage = null;

  function pageDom(data) {
    const frag = document.createDocumentFragment();
    const keys = Object.keys(data.frontmatter || {});
    if (keys.length) {
      const dl = document.createElement('dl');
      dl.className = 'doc-fm';
      keys.forEach((k) => {
        const dt = document.createElement('dt');
        dt.textContent = k;
        const dd = document.createElement('dd');
        dd.textContent = Array.isArray(data.frontmatter[k])
          ? data.frontmatter[k].join(', ')
          : data.frontmatter[k];
        dl.append(dt, dd);
      });
      frag.appendChild(dl);
    }
    const body = document.createElement('div');
    body.innerHTML = data.html; // our own server rendering local files
    frag.appendChild(body);
    return frag;
  }

  // Whatever fills the preview (page, search, front) takes a ticket; a
  // response that arrives after a later request bails, so a slow earlier
  // page can never overwrite the selection the reader has moved on to.
  let previewSeq = 0;

  async function showPage(path, name) {
    const my = ++previewSeq;
    previewEl.textContent = 'loading…';
    let res;
    try {
      res = await fetch(API_BASE + '/api/docs/page?path=' + encodeURIComponent(path));
    } catch {
      if (my === previewSeq) notice(`${name || path}: network error`);
      return;
    }
    if (my !== previewSeq) return;
    if (!res.ok) {
      const err = (await res.json().catch(() => ({}))).error || 'could not load';
      if (my === previewSeq) notice(`${name || path}: ${err}`);
      return;
    }
    const data = await res.json().catch(() => null);
    if (my !== previewSeq) return;
    if (!data || typeof data.html !== 'string') {
      notice(`${name || path}: could not load`);
      return;
    }
    currentPage = data;
    previewEl.textContent = '';
    previewEl.appendChild(pageDom(data));
    previewEl.dataset.path = data.path;
    appendBacklinks(data.path);
  }

  // What links here (BT-152) - always stated, so an empty list reads as an
  // answer rather than an omission.
  async function appendBacklinks(path) {
    const res = await fetch(API_BASE + '/api/docs/backlinks?path=' + encodeURIComponent(path));
    const links = await res.json().catch(() => []);
    if (previewEl.dataset.path !== path) return; // the reader moved on
    const head = document.createElement('div');
    head.className = 'sh-folder';
    head.textContent = 'linked from';
    previewEl.appendChild(head);
    if (!links.length) {
      const none = document.createElement('div');
      none.className = 'sh-line';
      none.textContent = 'nothing links to this page';
      previewEl.appendChild(none);
      return;
    }
    links.forEach((b) => {
      const row = document.createElement('div');
      row.className = 'search-hit';
      const p = document.createElement('div');
      p.className = 'sh-path';
      p.textContent = b.path;
      row.appendChild(p);
      row.addEventListener('click', () => {
        selectByPath(b.path);
        showPage(b.path);
      });
      previewEl.appendChild(row);
    });
  }

  // Act on the real file (BT-142/143): the buttons follow the deepest
  // selection - a page or a folder - and there is deliberately no in-browser
  // editing anywhere; the editor already open is better than any textarea.
  async function fileAction(action) {
    const node = selection[selection.length - 1];
    if (!node) return;
    if (action === 'editor' && node.type !== 'page') return;
    try {
      const res = await fetch(API_BASE + '/api/docs/' + action, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path: node.path }),
      });
      if (!res.ok) {
        // 400 = scope refusal, 501 = no launcher on this platform.
        const err = (await res.json().catch(() => ({}))).error;
        flash(err || `${action} failed (HTTP ${res.status})`);
      }
    } catch {
      flash(`network error - ${action} failed`);
    }
  }
  document.getElementById('doc-editor').addEventListener('click', () => fileAction('editor'));
  document.getElementById('doc-reveal').addEventListener('click', () => fileAction('reveal'));

  // Detail view (BT-141): the board's overlay component, one reused element.
  const detailEl = document.getElementById('doc-detail');
  document.getElementById('doc-expand').addEventListener('click', () => {
    if (!currentPage) return;
    document.getElementById('doc-detail-path').textContent = currentPage.path;
    document.getElementById('doc-detail-title').textContent = currentPage.title;
    const body = document.getElementById('doc-detail-body');
    body.textContent = '';
    body.appendChild(pageDom(currentPage));
    // The overlay already shows the title - the body's own # heading would
    // say it twice (BT-172).
    const h1 = body.querySelector('h1');
    if (h1) h1.remove();
    detailEl.classList.add('open');
  });
  function closeDetail() {
    detailEl.classList.remove('open');
  }
  document.getElementById('doc-detail-close').addEventListener('click', closeDetail);
  detailEl.addEventListener('click', (e) => {
    if (e.target === detailEl) closeDetail();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeDetail();
  });

  function notice(text) {
    previewEl.textContent = '';
    const p = document.createElement('p');
    p.className = 'doc-notice';
    p.textContent = text;
    previewEl.appendChild(p);
  }

  // A transient bar for a failed action - unlike notice() it leaves the page
  // in the preview alone.
  function flash(text) {
    const bar = document.createElement('div');
    bar.className = 'doc-flash';
    bar.textContent = text;
    document.body.appendChild(bar);
    setTimeout(() => bar.remove(), 6000);
  }

  // Walk the tree to a docs-relative path so a followed link also drives the
  // columns, keeping selection and preview in step (BT-140).
  function selectByPath(path) {
    const segs = path.split('/');
    selection = [];
    let nodes = tree;
    for (const seg of segs) {
      const node = (nodes || []).find((n) => n.name === seg);
      if (!node) {
        render();
        return false;
      }
      selection.push(node);
      nodes = node.children;
    }
    render();
    return true;
  }

  // Relative links inside a rendered page resolve inside the browser
  // (BT-140). A link that climbs out of the docs root is refused with the
  // page it came from named; the server refuses independently (BT-159) -
  // this check just makes the refusal instant and honest.
  previewEl.addEventListener('click', (e) => {
    const a = e.target.closest('a');
    if (!a || !previewEl.contains(a)) return;
    const href = a.getAttribute('href') || '';
    if (window.BTLogic.isExternalHref(href)) return; // http(s)/mailto behave normally
    e.preventDefault();
    const from = previewEl.dataset.path || '';
    if (/^[a-z][a-z0-9+.-]*:/i.test(href.trim())) {
      // javascript:, data:, ... - never handed to the browser. The server
      // sanitises too; this makes the refusal visible.
      notice(`refused: the link "${href}" in ${from} uses a scheme the browser must not follow`);
      return;
    }
    const target = window.BTLogic.resolveDocPath(from, href);
    if (target === null) {
      notice(`refused: the link "${href}" in ${from} leaves the docs root`);
      return;
    }
    if (selectByPath(target)) {
      showPage(target);
    } else {
      // Not in the tree - a non-renderable file or a missing one. Ask the
      // server anyway so the refusal carries its reason; reveal lands with
      // BT-143.
      showPage(target, target);
    }
  });

  // Search (BT-150): results replace the preview grouped by folder; opening a
  // hit drives the columns and scrolls the first match into view.
  const searchEl = document.getElementById('doc-search');
  let searchTimer = null;
  searchEl.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(runSearch, 250);
  });
  searchEl.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      searchEl.value = '';
      showFront();
    }
  });

  async function runSearch() {
    const q = searchEl.value.trim();
    if (!q) {
      showFront();
      return;
    }
    const my = ++previewSeq;
    let hits = null;
    try {
      const res = await fetch(API_BASE + '/api/docs/search?q=' + encodeURIComponent(q));
      if (res.ok) hits = await res.json().catch(() => null);
    } catch {
      hits = null;
    }
    if (my !== previewSeq) return;
    if (!Array.isArray(hits)) {
      notice('search failed');
      return;
    }
    previewEl.textContent = '';
    previewEl.dataset.path = '';
    if (!hits.length) {
      notice(`no matches for "${q}"`);
      return;
    }
    let lastFolder = null;
    hits.forEach((h) => {
      if (h.folder !== lastFolder) {
        lastFolder = h.folder;
        const f = document.createElement('div');
        f.className = 'sh-folder';
        f.textContent = h.folder === '.' ? 'docs' : h.folder;
        previewEl.appendChild(f);
      }
      const hit = document.createElement('div');
      hit.className = 'search-hit';
      const path = document.createElement('div');
      path.className = 'sh-path';
      path.textContent = h.path + ':' + h.lineno;
      const line = document.createElement('div');
      line.className = 'sh-line';
      const idx = h.line.toLowerCase().indexOf(q.toLowerCase());
      if (idx >= 0) {
        line.append(h.line.slice(0, idx));
        const mark = document.createElement('mark');
        mark.textContent = h.line.slice(idx, idx + q.length);
        line.append(mark, h.line.slice(idx + q.length));
      } else {
        line.textContent = h.line;
      }
      hit.append(path, line);
      hit.addEventListener('click', () => openHit(h.path, q));
      previewEl.appendChild(hit);
    });
  }

  async function openHit(path, q) {
    selectByPath(path);
    await showPage(path);
    // Scroll the first element containing the match into view.
    const needle = q.toLowerCase();
    const walker = document.createTreeWalker(previewEl, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      if (node.textContent.toLowerCase().includes(needle)) {
        (node.parentElement || previewEl).scrollIntoView({ block: 'center' });
        break;
      }
    }
  }

  // The landing surface (BT-149): the README is what you see before you
  // select anything, the version is a badge, and the changelog opens in the
  // overlay collapsed by version - newest expanded, never one wall.
  let front = {};
  let recent = [];
  function showFront() {
    ++previewSeq; // a page or search still in flight must not land on top
    previewEl.textContent = '';
    previewEl.dataset.path = '';
    if (recent.length) {
      const head = document.createElement('div');
      head.className = 'sh-folder';
      head.textContent = 'recently changed';
      previewEl.appendChild(head);
      recent.slice(0, 8).forEach((r) => {
        const row = document.createElement('div');
        row.className = 'search-hit';
        const p = document.createElement('div');
        p.className = 'sh-path';
        p.textContent = r.path;
        const d = document.createElement('div');
        d.className = 'sh-line';
        d.textContent = r.date;
        row.append(p, d);
        row.addEventListener('click', () => {
          selectByPath(r.path);
          showPage(r.path);
        });
        previewEl.appendChild(row);
      });
    }
    if (front.readme_html) {
      const readme = document.createElement('div');
      readme.innerHTML = front.readme_html;
      previewEl.appendChild(readme);
    }
  }

  function changelogDom(html) {
    const src = document.createElement('div');
    src.innerHTML = html;
    const out = document.createDocumentFragment();
    let details = null,
      first = true;
    [...src.childNodes].forEach((node) => {
      if (node.nodeName === 'H2') {
        details = document.createElement('details');
        if (first) {
          details.open = true;
          first = false;
        }
        const summary = document.createElement('summary');
        summary.textContent = node.textContent;
        details.appendChild(summary);
        out.appendChild(details);
      } else if (details) {
        details.appendChild(node);
      } else {
        out.appendChild(node);
      }
    });
    return out;
  }

  async function load() {
    let treeRes, frontRes, recentRes;
    try {
      [treeRes, frontRes, recentRes] = await Promise.all([
        fetch(API_BASE + '/api/docs/tree'),
        fetch(API_BASE + '/api/docs/front'),
        fetch(API_BASE + '/api/docs/recent'),
      ]);
    } catch {
      notice('network error - could not load docs');
      return;
    }
    tree = await treeRes.json().catch(() => null);
    front = await frontRes.json().catch(() => ({}));
    recent = await recentRes.json().catch(() => []);
    if (!Array.isArray(tree)) {
      tree = [];
      notice('could not load the docs tree');
      return;
    }
    if (!Array.isArray(recent)) recent = [];
    render();
    if (front.version) document.getElementById('doc-version').textContent = 'v' + front.version;
    if (front.version_ambiguous) {
      const v = document.getElementById('doc-version');
      v.textContent = 'version?';
      v.title =
        'Ambiguous: ' + front.version_ambiguous.join(' and ') + ' - set version: in dashboard.md';
    }
    if (front.changelog_html) {
      const link = document.getElementById('doc-changelog');
      link.style.display = '';
      link.addEventListener('click', () => {
        document.getElementById('doc-detail-path').textContent = 'CHANGELOG.md';
        document.getElementById('doc-detail-title').textContent = 'Changelog';
        const body = document.getElementById('doc-detail-body');
        body.textContent = '';
        body.appendChild(changelogDom(front.changelog_html));
        detailEl.classList.add('open');
      });
    }
    showFront();
  }
  load();
})();
