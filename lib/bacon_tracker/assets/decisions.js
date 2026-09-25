// Decisions board (BT-144): five columns, one per status directory, reusing
// the story board's structural components under data-status. Historical
// statuses collapse by default; accepted paginates the way done does.
(function () {
  const API_BASE = window.BT_API_BASE || '';
  const STATUSES = ['proposed', 'accepted', 'rejected', 'deprecated', 'superseded'];
  const COLLAPSED = new Set(['rejected', 'deprecated', 'superseded']);
  const PAGE_SIZE = 25;
  const boardEl = document.getElementById('decision-board');
  let records = [];
  let acceptedPage = 0;
  let dragged = null;

  function el(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined) n.textContent = text;
    return n;
  }

  function card(r) {
    const c = el('div', 'card dcard');
    c.dataset.id = r.id;
    c.draggable = true;
    c.addEventListener('dragstart', (e) => {
      e.dataTransfer.setData('text/plain', r.id);
      e.dataTransfer.effectAllowed = 'move';
      dragged = { id: r.id, status: r.status, el: c };
    });
    c.addEventListener('dragend', () => {
      dragged = null;
    });
    // Reorder within proposed (BT-147): the card follows the pointer live,
    // and the drop commits the DOM order - position is the priority.
    c.addEventListener('dragover', (e) => {
      if (!dragged || dragged.status !== 'proposed' || r.status !== 'proposed' || dragged.el === c)
        return;
      e.preventDefault();
      e.stopPropagation();
      const before = e.offsetY < c.offsetHeight / 2;
      c.parentNode.insertBefore(dragged.el, before ? c : c.nextSibling);
    });
    const idRow = el('div', 'card-id');
    idRow.appendChild(el('span', null, r.id));
    if (r.date) idRow.appendChild(el('span', 'd-date', r.date));
    if (r.docs_path) {
      // Inline in the id row, after the date - the absolute version sat on
      // top of it (BT-175).
      const rev = el('button', 'dcard-reveal', '↗');
      rev.title = 'Reveal the file';
      rev.addEventListener('click', (e) => {
        e.stopPropagation();
        revealRecord(r);
      });
      idRow.appendChild(rev);
    }
    c.appendChild(idRow);
    c.appendChild(el('div', 'd-title', r.title));
    if (r.superseded_by.length) {
      const s = el('div', 'd-succ', 'superseded by ');
      r.superseded_by.forEach((id) => {
        const a = el('a', null, id);
        a.addEventListener('click', (e) => {
          e.stopPropagation();
          jumpTo(id);
        });
        s.appendChild(a);
      });
      c.appendChild(s);
    }
    if (r.canonical) c.appendChild(el('div', 'd-succ', 'adopts ' + r.canonical));
    if (r.stories.length) {
      const row = el('div', 'd-succ');
      r.stories.forEach((sid) => {
        if (window.BTLogic.sameNamespace(r.id, sid)) {
          const a = el('a', null, sid);
          a.title = 'Jump to the story';
          a.addEventListener('click', (e) => {
            e.stopPropagation();
            window.location = boardBase() + '#' + sid;
          });
          row.appendChild(a);
        } else {
          // Another namespace: plain text, never a link that lies (BT-ADR-0013).
          row.appendChild(el('span', null, sid));
        }
        row.appendChild(document.createTextNode(' '));
      });
      c.appendChild(row);
    }
    c.addEventListener('click', () => openDetail(r));
    return c;
  }

  function jumpTo(id) {
    const target = records.find((r) => r.id === id);
    if (target) openDetail(target);
  }

  function boardBase() {
    return API_BASE || '/';
  }

  // 400 = scope refusal, 501 = no launcher on this platform - both say why.
  async function revealRecord(r) {
    try {
      const res = await fetch(API_BASE + '/api/docs/reveal', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path: r.docs_path }),
      });
      if (!res.ok) {
        const err = (await res.json().catch(() => ({}))).error;
        flashError(err || `reveal failed (HTTP ${res.status})`);
      }
    } catch {
      flashError('network error - reveal failed');
    }
  }

  async function openDetail(r) {
    const pathEl = document.getElementById('doc-detail-path');
    pathEl.textContent = r.id;
    // The status directory is authoritative, so the overlay states it as the
    // board does - a pill in the status' colour, not prose in the id line
    // (BT-178).
    const statusEl = document.getElementById('doc-detail-status');
    statusEl.textContent = r.status;
    statusEl.dataset.status = r.status;
    // Reveal and supersession sit after the pill so the head reads
    // id · status · where else to go.
    const refsEl = document.getElementById('doc-detail-refs');
    refsEl.textContent = '';
    if (r.docs_path) {
      const rev = el('a', null, '↗');
      rev.title = 'Reveal the file';
      rev.style.cursor = 'pointer';
      rev.addEventListener('click', () => revealRecord(r));
      refsEl.appendChild(rev);
    }
    // Supersession is navigable in both directions (BT-148).
    [
      ['supersedes', r.supersedes],
      ['superseded by', r.superseded_by],
    ].forEach(([label, ids]) => {
      (ids || []).forEach((id) => {
        refsEl.appendChild(document.createTextNode((refsEl.firstChild ? ' · ' : '') + label + ' '));
        const a = el('a', null, id);
        a.style.cursor = 'pointer';
        a.addEventListener('click', () => jumpTo(id));
        refsEl.appendChild(a);
      });
    });
    document.getElementById('doc-detail-title').textContent = r.title;
    const body = document.getElementById('doc-detail-body');
    body.textContent = 'loading…';
    document.getElementById('doc-detail').classList.add('open');
    if (!r.docs_path) {
      body.textContent = '(not reachable through the docs surface)';
      return;
    }
    let page = null;
    try {
      const res = await fetch(API_BASE + '/api/docs/page?path=' + encodeURIComponent(r.docs_path));
      if (res.ok) page = await res.json().catch(() => null);
    } catch {
      page = null;
    }
    if (!page || typeof page.html !== 'string') {
      body.textContent = 'could not load';
      return;
    }
    body.innerHTML = page.html; // sanitised server-side (render_markdown)
    // The overlay head already carries id, status and title - the body's own
    // # heading would say the title twice (BT-172).
    const h1 = body.querySelector('h1');
    if (h1) h1.remove();
  }

  function column(status) {
    const col = el('section', 'column');
    col.dataset.status = status;
    // Drops render the primitive's rules (BT-ADR-0017): the transition is one
    // PUT, the server validates, and the superseded column never accepts a
    // bare drop - it opens the target picker instead.
    col.addEventListener('dragover', (e) => {
      e.preventDefault();
      col.classList.add('drop-target');
    });
    col.addEventListener('dragleave', () => col.classList.remove('drop-target'));
    col.addEventListener('drop', async (e) => {
      e.preventDefault();
      col.classList.remove('drop-target');
      const id = e.dataTransfer.getData('text/plain');
      if (!id) return;
      if (status === 'proposed' && dragged && dragged.status === 'proposed') {
        const ids = [...col.querySelectorAll('.dcard')].map((n) => n.dataset.id);
        try {
          const res = await fetch(API_BASE + '/api/decisions/proposed/order', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ids }),
          });
          if (!res.ok) {
            const err = (await res.json().catch(() => ({}))).error;
            flashError(err || 'reorder refused');
          }
        } catch {
          flashError('network error - reorder not saved');
        }
        await reload();
      } else if (status === 'superseded') {
        openPicker(id);
      } else {
        transition(id, status);
      }
    });
    const inStatus = records.filter((r) => r.status === status);

    const head = el('div', 'col-header');
    const label = el('div', 'col-label');
    const h2 = el('h2', null, status);
    label.appendChild(h2);
    label.appendChild(el('span', 'col-sublabel', String(inStatus.length)));
    head.appendChild(label);
    // No "+ new" on the board (BT-174): a record created from a prompt is
    // boilerplate that goes stale - a decision starts in the editor, via
    // `rake decision:new` or the skill. The API and Rake surfaces stay.
    if (COLLAPSED.has(status)) {
      const toggle = el('button', 'col-toggle', '⇔');
      toggle.title = 'expand/collapse';
      toggle.addEventListener('click', () => col.classList.toggle('collapsed'));
      head.appendChild(toggle);
      if (localStorage.getItem('bt-dec-' + status) !== 'open') col.classList.add('collapsed');
      toggle.addEventListener('click', () =>
        localStorage.setItem('bt-dec-' + status, col.classList.contains('collapsed') ? '' : 'open')
      );
    }
    col.appendChild(head);

    const cards = el('div', 'cards');
    let visible = inStatus;
    if (status === 'accepted' && inStatus.length > PAGE_SIZE) {
      const pages = Math.ceil(inStatus.length / PAGE_SIZE);
      acceptedPage = Math.min(acceptedPage, pages - 1);
      visible = inStatus.slice(acceptedPage * PAGE_SIZE, (acceptedPage + 1) * PAGE_SIZE);
      const pager = el('div', 'pagination');
      const prev = el('button', null, '‹');
      const next = el('button', null, '›');
      prev.disabled = acceptedPage === 0;
      next.disabled = acceptedPage >= pages - 1;
      prev.addEventListener('click', () => {
        acceptedPage--;
        render();
      });
      next.addEventListener('click', () => {
        acceptedPage++;
        render();
      });
      pager.append(prev, el('span', null, acceptedPage + 1 + '/' + pages), next);
      col.appendChild(cards);
      col.appendChild(pager);
    } else {
      col.appendChild(cards);
    }
    visible.forEach((r) => cards.appendChild(card(r)));
    return col;
  }

  function render() {
    boardEl.textContent = '';
    STATUSES.forEach((s) => boardEl.appendChild(column(s)));
  }

  function closeDetail() {
    document.getElementById('doc-detail').classList.remove('open');
  }
  document.getElementById('doc-detail-close').addEventListener('click', closeDetail);
  document.getElementById('doc-detail').addEventListener('click', (e) => {
    if (e.target.id === 'doc-detail') closeDetail();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    closePicker(); // the picker would otherwise trap the board until ✕
    closeDetail();
  });

  async function transition(id, status, supersededBy) {
    let res;
    try {
      res = await fetch(API_BASE + '/api/decisions/' + encodeURIComponent(id) + '/status', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status, superseded_by: supersededBy }),
      });
    } catch {
      flashError('network error - transition not saved');
      return;
    }
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      flashError(data.error || 'transition refused');
      return;
    }
    if (data.external && data.external.length) {
      flashError(
        `${data.external.join(', ')} is in another namespace - its supersedes side was NOT written; record it there`,
        true
      );
    }
    await reload();
  }

  function flashError(text, info) {
    const bar = el('div', 'board-flash' + (info ? ' info' : ''), text);
    document.body.appendChild(bar);
    setTimeout(() => bar.remove(), info ? 9000 : 6000);
  }

  // The supersede target picker (BT-145): a drop on superseded is completed
  // with a target or not at all. Candidates are the accepted records; the free
  // field takes a cross-namespace id, whose other side the server will
  // truthfully report as unwritten.
  const pickerEl = document.getElementById('supersede-picker');
  function openPicker(id) {
    document.getElementById('picker-subject').textContent = id;
    const list = document.getElementById('picker-list');
    list.textContent = '';
    window.BTLogic.supersedeCandidates(records, id).forEach((cand) => {
      const b = el('button', 'picker-cand', cand);
      b.addEventListener('click', () => {
        closePicker();
        transition(id, 'superseded', cand);
      });
      list.appendChild(b);
    });
    const input = document.getElementById('picker-free');
    input.value = '';
    pickerEl.classList.add('open');
    input.focus();
  }
  function closePicker() {
    pickerEl.classList.remove('open');
  }
  document.getElementById('picker-cancel').addEventListener('click', closePicker);
  pickerEl.addEventListener('click', (e) => {
    if (e.target === pickerEl) closePicker();
  });
  document.getElementById('picker-free').addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    const v = e.target.value.trim();
    if (!v) return;
    const id = document.getElementById('picker-subject').textContent;
    closePicker();
    transition(id, 'superseded', v);
  });

  // A 500's {error} object or a dropped connection must not become
  // "records.filter is not a function" - keep the last good board and say so.
  async function reload() {
    let next = null;
    try {
      const res = await fetch(API_BASE + '/api/decisions');
      next = await res.json().catch(() => null);
    } catch {
      next = null;
    }
    if (!Array.isArray(next)) {
      flashError((next && next.error) || 'could not load the decisions');
      return false;
    }
    records = next;
    render();
    return true;
  }

  (async function load() {
    if (!(await reload())) return;
    const id = window.BTLogic.hashId(location.hash);
    if (id) jumpTo(id);
  })();
})();
