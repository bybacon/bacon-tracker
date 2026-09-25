const DONE_PER_PAGE = 20;
const API_BASE = window.BT_API_BASE || '';
let data = null;
let meta = null;
let donePage = 1;
const STAGE_KEYS = {
  '1_icebox': 'icebox',
  '2_backlog': 'backlog',
  '3_started': 'started',
  '4_done': 'done',
};
let dragged = null;
let draggedStage = null;
// undefined = no drop position shown yet; null = "append at the end".
let insertBeforeCard;
let activeMobileStage = localStorage.getItem('bt-mobile-tab') || '2_backlog';
// The /…#NS-042 deep link (BT-148) is honoured once, on the first load -
// later reloads (after a relation edit) must not yank the scroll back.
let deepLinkHandled = false;

// ── Data ──────────────────────────────────────────────────────────────────

async function load() {
  const errBar = document.getElementById('load-error');
  try {
    const r = await fetch(API_BASE + '/api/stories');
    if (!r.ok) throw new Error('HTTP ' + r.status);
    data = await r.json();
  } catch {
    errBar.style.display = '';
    return;
  }
  errBar.style.display = 'none';
  render();
  if (!deepLinkHandled) {
    deepLinkHandled = true;
    const id = BTLogic.hashId(location.hash);
    if (id && storyExists(id)) gotoStory(id);
  }
}

function render() {
  renderStage('1_icebox', data.icebox);
  renderStage('2_backlog', data.backlog);
  renderStage('3_started', data.started || []);
  renderDone();
  renderNextBar();
  updateTabCounts();
  if (data.meta) {
    meta = data.meta;
    const btn = document.getElementById('btn-reveal-backlog');
    if (btn) {
      btn.style.display = '';
      btn.onclick = () => revealPath(meta.backlog_path);
    }
  }
}

// Re-render one column from the data arrays (done has its own renderer
// because of pagination).
function renderColumn(stage) {
  if (stage === '4_done') renderDone();
  else renderStage(stage, data[STAGE_KEYS[stage]] || []);
}

function renderStage(stage, stories) {
  const col = document.querySelector(`[data-stage="${stage}"]`);
  const cards = col.querySelector('.cards');
  col.querySelector('.count').textContent = stories.length;
  cards.innerHTML = '';
  if (stories.length === 0) {
    const msgs = {
      '1_icebox': ['No ideas yet', 'use + to capture a maybe'],
      '2_backlog': ['Backlog empty', 'use + to commit a story'],
      '3_started': ['Nothing started', 'drag a backlog card here'],
      '4_done': ['Nothing done yet', null],
    };
    const [text, hint] = msgs[stage] || ['Empty', null];
    const es = el('div', { className: 'empty-state' });
    es.innerHTML = `<div><p>${text}</p>${hint ? `<p class="hint">${hint}</p>` : ''}</div>`;
    cards.appendChild(es);
  } else {
    stories.forEach((s) => cards.appendChild(makeCard(s, stage)));
  }
}

function renderDone() {
  const stories = data.done;
  const col = document.querySelector('[data-stage="4_done"]');
  col.querySelector('.count').textContent = stories.length;
  const maxPage = Math.max(1, Math.ceil(stories.length / DONE_PER_PAGE));
  donePage = Math.min(donePage, maxPage);
  const slice = stories.slice((donePage - 1) * DONE_PER_PAGE, donePage * DONE_PER_PAGE);
  const cards = col.querySelector('.cards');
  cards.innerHTML = '';
  if (!slice.length) {
    const es = el('div', { className: 'empty-state' });
    es.innerHTML = '<div><p>Nothing done yet</p></div>';
    cards.appendChild(es);
  } else {
    slice.forEach((s) => cards.appendChild(makeCard(s, '4_done')));
  }
  const pager = col.querySelector('.pagination');
  pager.innerHTML = '';
  if (stories.length > DONE_PER_PAGE) {
    const btn = (label, fn) => {
      const b = document.createElement('button');
      b.textContent = label;
      b.onclick = fn;
      return b;
    };
    if (donePage > 1)
      pager.appendChild(
        btn('← prev', () => {
          donePage--;
          renderDone();
        })
      );
    const info = document.createElement('span');
    info.textContent = `${donePage} / ${maxPage}`;
    pager.appendChild(info);
    if (donePage < maxPage)
      pager.appendChild(
        btn('next →', () => {
          donePage++;
          renderDone();
        })
      );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────

// Relationship badges for a story, in one place so cards and the detail
// modal render them identically: blocked_by (⛔ red - this story is stuck),
// the derived reverse `blocks` (⛔ amber - this story holds another up), and
// the symmetric link (🔗 - the union of linked_to and the derived
// linked_from, deduped). A badge pointing at a known story is clickable;
// onJump(id) opens it in the detail view, from a card and from the detail
// view alike (BT-178). `blocks`/`linked_from` are derived server-side
// over the whole board (a file-based tracker stores each relation on one
// side only), so they arrive on the board GET but not on a single-story PUT.
function relationBadges(story, onJump) {
  const badges = [];
  const add = (id, cls, text, label) => {
    const exists = storyExists(id);
    const badge = el(
      'span',
      {
        className: exists ? `meta-badge ${cls} link` : `meta-badge ${cls}`,
        title: exists ? `${label} ${id} - click to open` : `${label} ${id} (not found)`,
      },
      text
    );
    if (exists)
      badge.addEventListener('click', (e) => {
        e.stopPropagation();
        onJump(id);
      });
    badges.push(badge);
  };
  (story.blocked_by || []).forEach((id) => add(id, 'blocked', `⛔ ${id}`, 'Blocked by'));
  (story.blocks || []).forEach((id) => add(id, 'blocks', `⛔ blocks ${id}`, 'Blocks'));
  [...new Set([...(story.linked_to || []), ...(story.linked_from || [])])].forEach((id) =>
    add(id, 'linked', `🔗 ${id}`, 'Linked to')
  );
  // Decisions citing this story (BT-148) live on another board - the badge
  // navigates there and the decisions board opens the record from the hash.
  (story.decisions || []).forEach((id) => {
    const badge = el(
      'span',
      { className: 'meta-badge linked link', title: `Decided in ${id} - click to open` },
      `§ ${id}`
    );
    badge.addEventListener('click', (e) => {
      e.stopPropagation();
      window.location = `${API_BASE}/docs/decisions#${id}`;
    });
    badges.push(badge);
  });
  return badges;
}

function fillCardHeader(headerEl, story, onEdit, onReveal, onExpand) {
  while (headerEl.firstChild) headerEl.removeChild(headerEl.firstChild);
  const kids = [
    el('span', { className: `badge ${story.type}` }, story.type),
    el('span', { className: 'card-id' }, story.id),
  ];
  if (story.size) kids.push(el('span', { className: 'meta-badge' }, story.size));
  if (story.subtasks && story.subtasks.total)
    kids.push(
      el(
        'span',
        { className: 'meta-badge subtask-progress', title: 'subtasks done' },
        `${story.subtasks.done}/${story.subtasks.total}`
      )
    );
  relationBadges(story, openStoryDetail).forEach((b) => kids.push(b));
  if (story.assignee) kids.push(el('span', { className: 'meta-badge' }, story.assignee));
  const btnEdit = el('button', { className: 'btn-edit' }, 'edit');
  btnEdit.addEventListener('click', (e) => {
    e.stopPropagation();
    onEdit();
  });
  const btnRevl = el('button', { className: 'btn-reveal-story', title: 'Reveal the file', 'aria-label': 'Reveal the file' }, '↗');
  btnRevl.addEventListener('click', (e) => {
    e.stopPropagation();
    onReveal();
  });
  kids.push(btnEdit, btnRevl);
  if (onExpand) {
    const btnExpand = el(
      'button',
      { className: 'btn-expand', title: 'Open detail view', 'aria-label': 'Open detail view' },
      '⤢'
    );
    btnExpand.addEventListener('click', (e) => {
      e.stopPropagation();
      onExpand();
    });
    kids.push(btnExpand);
  }
  kids.forEach((k) => headerEl.appendChild(k));
}

// Shared subtask click→toggle for any body-preview element (card + detail
// modal). getStory is a thunk so the same handler can serve a modal whose
// story changes on each open.
function attachSubtaskToggle(previewEl, getStory, afterUpdate) {
  previewEl.addEventListener('click', (e) => {
    const t = e.target.closest('.subtask');
    if (!t) return;
    e.stopPropagation();
    toggle(t);
  });
  // Subtasks render as role="checkbox" with tabindex=0 - Space/Enter tick them.
  previewEl.addEventListener('keydown', (e) => {
    const t = e.target.closest('.subtask');
    if (!t || (e.key !== ' ' && e.key !== 'Enter')) return;
    e.preventDefault();
    e.stopPropagation();
    toggle(t);
  });
  async function toggle(t) {
    // Ignore a second click while the first is still in flight - otherwise
    // both read the same pre-render classList and send the same `done`,
    // and a stale index could toggle the wrong line (BT-112).
    if (t.dataset.busy) return;
    t.dataset.busy = '1';
    const story = getStory();
    const idx = parseInt(t.dataset.idx, 10);
    const done = !t.classList.contains('done');
    try {
      const res = await api('PUT', API_BASE + `/api/stories/${story.id}/subtasks`, {
        index: idx,
        done,
      });
      if (res.ok) {
        const j = await res.json();
        story.body = toggleSubtaskInBody(story, idx, done);
        story.subtasks = j.subtasks;
        afterUpdate(story);
      } else {
        const err = await res.json().catch(() => ({}));
        alert(err.error || 'Failed to update subtask');
      }
    } catch {
      alert('Network error - failed to update subtask');
    } finally {
      delete t.dataset.busy;
    }
  }
}

// Story detail modal (BT-070): one overlay reused for any story. Opened from
// a card's maximize button; the board stays mounted behind it.
let detailStory = null,
  detailOnChange = null,
  detailEls = null;

function ensureDetailModal() {
  if (detailEls) return detailEls;
  const head = el('div', { className: 'detail-head' });
  const titleEl = el('div', { className: 'detail-title' });
  const bodyEl = el('div', { className: 'detail-body body-preview' });
  const modal = el('div', { className: 'detail-modal' }, [head, titleEl, bodyEl]);
  const backdrop = el('div', { className: 'detail-backdrop' }, [modal]);
  document.body.appendChild(backdrop);

  backdrop.addEventListener('click', (e) => {
    if (e.target === backdrop) closeDetail();
  });
  attachSubtaskToggle(
    bodyEl,
    () => detailStory,
    () => {
      renderDetail();
      if (detailOnChange) detailOnChange();
    }
  );

  detailEls = { backdrop, head, titleEl, bodyEl };
  return detailEls;
}

function renderDetail() {
  const { head, titleEl, bodyEl } = detailEls;
  const s = detailStory;
  while (head.firstChild) head.removeChild(head.firstChild);
  head.appendChild(el('span', { className: `badge ${s.type}` }, s.type));
  head.appendChild(el('span', { className: 'detail-id' }, s.id));
  if (s.stage)
    head.appendChild(
      el(
        'span',
        { className: 'detail-stage', 'data-stage': s.stage, title: 'Current stage' },
        STAGE_KEYS[s.stage] || s.stage
      )
    );
  if (s.size) head.appendChild(el('span', { className: 'meta-badge' }, s.size));
  if (s.subtasks && s.subtasks.total)
    head.appendChild(
      el(
        'span',
        { className: 'meta-badge subtask-progress' },
        `${s.subtasks.done}/${s.subtasks.total}`
      )
    );
  relationBadges(s, openStoryDetail).forEach((b) => head.appendChild(b));
  if (s.assignee) head.appendChild(el('span', { className: 'meta-badge' }, s.assignee));
  const closeBtn = el('button', { className: 'detail-close', title: 'Close (Esc)' }, '✕');
  closeBtn.addEventListener('click', closeDetail);
  head.appendChild(closeBtn);
  titleEl.textContent = s.title;
  bodyEl.innerHTML = renderBody(s);
}

function openDetail(story, onChange) {
  ensureDetailModal();
  detailStory = story;
  detailOnChange = onChange || null;
  renderDetail();
  detailEls.backdrop.classList.add('open');
  document.addEventListener('keydown', detailEscHandler);
}

// A relation badge (BT-178) opens the story it names in the detail view -
// from a card, and from the detail view itself, where it swaps the overlay
// to the referenced story rather than closing it to hunt down a card that
// may be paginated away or filtered out. Changes made there re-render the
// column the story actually lives in.
function openStoryDetail(id) {
  const target = storyById(id);
  if (!target) return;
  openDetail(target, () => {
    renderColumn(target.stage);
    renderNextBar();
  });
}

function closeDetail() {
  if (!detailEls) return;
  detailEls.backdrop.classList.remove('open');
  detailStory = null;
  detailOnChange = null;
  document.removeEventListener('keydown', detailEscHandler);
}

function detailEscHandler(e) {
  if (e.key === 'Escape') closeDetail();
}

function makeCard(story, stage) {
  const div = el('div', {
    className: `card type-${story.type}`,
    draggable: 'true',
    'data-id': story.id,
  });

  // View mode
  const viewMode = el('div', { className: 'card-view' });

  const header = el('div', { className: 'card-header' });

  const titleEl = el('span', { className: 'card-title' }, story.title);
  const chevron = el('span', { className: 'expand-chevron' }, '▾');
  const titleRow = el(
    'div',
    { className: 'card-title-row', role: 'button', tabindex: '0', 'aria-expanded': 'false' },
    [titleEl, chevron]
  );

  const preview = el('div', { className: 'body-preview' });
  const bodyWrap = el('div', { className: 'card-body' }, [preview]);
  function syncPreview() {
    preview.innerHTML = renderBody(story);
  }
  syncPreview();

  const revealCb = () => {
    if (story.path) revealPath(story.path);
  };
  function expandCb() {
    openDetail(story, syncCard);
  }
  function syncCard() {
    syncPreview();
    fillCardHeader(header, story, enterEdit, revealCb, expandCb);
  }

  attachSubtaskToggle(preview, () => story, syncCard);

  const toggleBody = () => {
    titleRow.setAttribute('aria-expanded', String(div.classList.toggle('body-expanded')));
  };
  titleRow.addEventListener('click', toggleBody);
  titleRow.addEventListener('keydown', (e) => {
    if (e.target !== titleRow || (e.key !== 'Enter' && e.key !== ' ')) return;
    e.preventDefault();
    toggleBody();
  });

  viewMode.append(header, titleRow, bodyWrap);

  // Edit mode - built lazily on first edit: most cards are never edited,
  // and the edit subtree is ~20 hidden nodes plus a dozen listeners.
  let editUi = null;

  function enterEdit() {
    editUi ||= buildEdit();
    editUi.open();
  }

  function buildEdit() {
    const editMode = el('div', { className: 'card-edit' });
    const editHeader = el('div', { className: 'edit-header' }, [
      el('span', { className: `badge ${story.type}` }, story.type),
      el('span', { className: 'card-id' }, story.id),
    ]);
    const titleInput = el('input', {
      className: 'title-input',
      type: 'text',
      placeholder: 'Title...',
    });

    let currentSize = story.size || null;
    const sizeBtns = {};
    const szPicker = el('div', { className: 'size-picker' });
    ['S', 'M', 'L'].forEach((s) => {
      const b = el('button', { className: 'size-btn' + (currentSize === s ? ' active' : '') }, s);
      b.addEventListener('click', () => {
        currentSize = currentSize === s ? null : s;
        Object.values(sizeBtns).forEach((x) => x.classList.remove('active'));
        if (currentSize && sizeBtns[currentSize]) sizeBtns[currentSize].classList.add('active');
      });
      sizeBtns[s] = b;
      szPicker.appendChild(b);
    });
    const szRow = el('div', { className: 'field-row' }, [
      el('span', { className: 'field-label' }, 'size:'),
      szPicker,
    ]);

    const assigneeIn = el('input', {
      className: 'field-input narrow',
      type: 'text',
      placeholder: 'AB',
      maxlength: '4',
    });
    const assigneeRow = el('div', { className: 'field-row' }, [
      el('span', { className: 'field-label' }, 'assignee:'),
      assigneeIn,
    ]);

    const blockedIn = el('input', {
      className: 'field-input wide',
      type: 'text',
      placeholder: 'BT-002, BT-003',
    });
    const blockedRow = el('div', { className: 'field-row' }, [
      el('span', { className: 'field-label' }, 'blocked by:'),
      blockedIn,
    ]);

    const linkedIn = el('input', {
      className: 'field-input wide',
      type: 'text',
      placeholder: 'BT-004, BT-010',
    });
    const linkedRow = el('div', { className: 'field-row' }, [
      el('span', { className: 'field-label' }, 'linked to:'),
      linkedIn,
    ]);

    // The non-drag way to move a story (keyboard and touch users). Done is
    // append-only, so a done card shows its stage but cannot leave it.
    const stageSel = el('select', { className: 'field-input', 'aria-label': 'Stage' });
    Object.entries(STAGE_KEYS).forEach(([value, label]) =>
      stageSel.appendChild(el('option', { value }, label))
    );
    const stageRow = el('div', { className: 'field-row' }, [
      el('span', { className: 'field-label' }, 'stage:'),
      stageSel,
    ]);

    const bodyEditor = el('textarea', {
      className: 'body-editor',
      placeholder: 'Markdown or Gherkin...',
    });

    const actions = el('div', { className: 'card-actions' }, [
      el('button', { className: 'btn-danger' }, 'delete'),
      el('div', { className: 'flex-spacer' }),
      el('button', { className: 'btn-secondary' }, 'cancel'),
      el('button', { className: 'btn-primary' }, 'save'),
    ]);

    editMode.append(
      editHeader,
      titleInput,
      szRow,
      stageRow,
      assigneeRow,
      blockedRow,
      linkedRow,
      bodyEditor,
      actions
    );
    div.appendChild(editMode);

    function open() {
      currentSize = story.size || null;
      Object.entries(sizeBtns).forEach(([k, b]) => b.classList.toggle('active', k === currentSize));
      assigneeIn.value = story.assignee || '';
      blockedIn.value = (story.blocked_by || []).join(', ');
      linkedIn.value = (story.linked_to || []).join(', ');
      stageSel.value = stage;
      stageSel.disabled = stage === '4_done';
      div.draggable = false;
      titleInput.value = story.title;
      bodyEditor.value = story.body || '';
      viewMode.style.display = 'none';
      editMode.style.display = 'block';
      div.classList.add('editing');
      titleInput.focus();
      titleInput.select();
    }

    function close() {
      viewMode.style.display = '';
      editMode.style.display = '';
      div.classList.remove('editing', 'body-expanded');
      div.draggable = true;
    }

    actions.querySelector('.btn-secondary').addEventListener('click', close);

    actions.querySelector('.btn-primary').addEventListener('click', async () => {
      const newTitle = titleInput.value.trim();
      if (!newTitle) return;
      const newBlocked = blockedIn.value.trim()
        ? blockedIn.value
            .trim()
            .split(/\s*,\s*/)
            .filter(Boolean)
        : [];
      const oldBlocked = story.blocked_by || [];
      const newLinked = linkedIn.value.trim()
        ? linkedIn.value
            .trim()
            .split(/\s*,\s*/)
            .filter(Boolean)
        : [];
      const oldLinked = story.linked_to || [];
      const newAssignee = assigneeIn.value.trim().toUpperCase();

      const changed = {};
      if (newTitle !== story.title) changed.title = newTitle;
      if (bodyEditor.value !== (story.body || '')) changed.body = bodyEditor.value;
      if (currentSize !== (story.size || null)) changed.size = currentSize || '';
      if (newBlocked.join(',') !== oldBlocked.join(',')) changed.blocked_by = newBlocked;
      if (newLinked.join(',') !== oldLinked.join(',')) changed.linked_to = newLinked;
      if (newAssignee !== (story.assignee || '')) changed.assignee = newAssignee;

      // A changed relationship flips a badge on the *other* story too, and the
      // single-story PUT response can't carry the board-wide derived ends -
      // reload so every reverse badge is fresh (BT-119). Deferred until after
      // any stage move, so the reload can't race the move.
      const needsReload = 'blocked_by' in changed || 'linked_to' in changed;
      if (Object.keys(changed).length > 0) {
        try {
          const res = await api('PUT', API_BASE + `/api/stories/${story.id}`, changed);
          if (res.ok) {
            // The response is the re-parsed story - fresh title/body/path
            // and derived fields (subtasks, subtask_lines) in one merge.
            Object.assign(story, await res.json());
            titleEl.textContent = story.title;
            syncCard();
            renderNextBar();
          } else {
            // Keep edit mode open with the user's text intact - a 400 for one
            // mistyped id must not throw away a long body edit (BT-179).
            const err = await res.json().catch(() => ({}));
            alert(err.error || 'Failed to save story');
            return;
          }
        } catch {
          alert('Network error - failed to save story');
          return;
        }
      }
      if (stageSel.value !== stage && !(await moveStory(story.id, stage, stageSel.value))) return;
      if (needsReload) load();
      close();
    });

    actions.querySelector('.btn-danger').addEventListener('click', async () => {
      if (!confirm(`Delete ${story.id} - ${story.title}?`)) return;
      try {
        const res = await api('DELETE', API_BASE + `/api/stories/${story.id}`);
        if (res.ok) {
          div.remove();
          const col = document.querySelector(`[data-stage="${stage}"]`);
          const cnt = col.querySelector('.count');
          cnt.textContent = Math.max(0, parseInt(cnt.textContent) - 1);
          ['icebox', 'backlog', 'started', 'done'].forEach((k) => {
            if (data[k]) data[k] = data[k].filter((s) => s.id !== story.id);
          });
          if (stage === '4_done') renderDone(); // keeps pagination backfilled and clamped
          updateTabCounts();
          renderNextBar();
        } else {
          const err = await res.json().catch(() => ({}));
          alert(err.error || 'Failed to delete story');
        }
      } catch {
        alert('Network error - failed to delete story');
      }
    });

    titleInput.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') close();
      if (e.key === 'Enter') actions.querySelector('.btn-primary').click();
    });
    bodyEditor.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') close();
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        actions.querySelector('.btn-primary').click();
      }
    });

    return { open, close };
  }

  syncCard();

  // Drag
  div.addEventListener('dragstart', (e) => {
    if (div.classList.contains('editing')) {
      e.preventDefault();
      return;
    }
    dragged = div;
    draggedStage = stage;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', story.id);
    e.dataTransfer.setData('text/x-source-stage', stage);
    requestAnimationFrame(() => div.classList.add('dragging'));
  });
  div.addEventListener('dragend', () => {
    div.classList.remove('dragging');
    cleanupDrag();
    dragged = null;
    draggedStage = null;
    insertBeforeCard = undefined;
  });

  div.append(viewMode);
  return div;
}

// ── Create form ───────────────────────────────────────────────────────────

function setupCreateForm(col) {
  const stage = col.dataset.stage;
  const addBtn = col.querySelector('.btn-add');
  if (!addBtn) return;

  const formEl = col.querySelector('.create-form');
  let activeType = 'feature';
  const typeBtns = {};
  const typeRow = el('div', { className: 'create-type-row' });

  ['feature', 'bug', 'chore'].forEach((t) => {
    const b = el(
      'button',
      { className: 'type-btn' + (t === 'feature' ? ' active' : ''), 'data-type': t },
      t
    );
    b.addEventListener('click', () => {
      activeType = t;
      Object.values(typeBtns).forEach((x) => x.classList.remove('active'));
      b.classList.add('active');
    });
    typeBtns[t] = b;
    typeRow.appendChild(b);
  });

  const titleInput = el('input', {
    className: 'create-title',
    type: 'text',
    placeholder: 'Story title...',
  });
  const inputRow = el('div', { className: 'create-input-row' }, [
    titleInput,
    el('button', { className: 'btn-create-submit' }, 'add'),
    el('button', { className: 'btn-create-cancel' }, '✕'),
  ]);
  formEl.append(typeRow, inputRow);

  function openForm() {
    formEl.style.display = 'flex';
    addBtn.style.opacity = '0.4';
    addBtn.style.pointerEvents = 'none';
    titleInput.value = '';
    titleInput.focus();
  }
  function closeForm() {
    formEl.style.display = '';
    addBtn.style.opacity = '';
    addBtn.style.pointerEvents = '';
  }

  addBtn.addEventListener('click', openForm);
  inputRow.querySelector('.btn-create-cancel').addEventListener('click', closeForm);
  titleInput.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeForm();
    if (e.key === 'Enter') inputRow.querySelector('.btn-create-submit').click();
  });

  const submitBtn = inputRow.querySelector('.btn-create-submit');
  submitBtn.addEventListener('click', async () => {
    const title = titleInput.value.trim();
    if (!title) {
      titleInput.focus();
      return;
    }
    // Disable while the POST is in flight so a double-click or Enter
    // autorepeat can't create duplicate stories (BT-112). A disabled
    // button also makes the Enter-key `.click()` above a no-op.
    if (submitBtn.disabled) return;
    submitBtn.disabled = true;
    try {
      const res = await api('POST', API_BASE + '/api/stories', { type: activeType, title, stage });
      if (res.ok) {
        // The 201 body is the created story - no need to refetch the board.
        const story = await res.json();
        const key = STAGE_KEYS[stage];
        (data[key] ||= []).push(story);
        closeForm();
        renderColumn(stage);
        renderNextBar();
        updateTabCounts();
      } else {
        const err = await res.json().catch(() => ({}));
        alert(err.error || 'Failed to create story');
      }
    } catch {
      alert('Network error - failed to create story');
    } finally {
      submitBtn.disabled = false;
    }
  });
}

// ── Drop zones ────────────────────────────────────────────────────────────

function setupDropZones() {
  document.querySelectorAll('.column').forEach((col) => {
    const stage = col.dataset.stage;
    const cardsEl = col.querySelector('.cards');

    col.addEventListener('dragover', (e) => {
      if (!dragged) return;
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      if (stage === '2_backlog' && draggedStage === '2_backlog') {
        const tgt = cardAfter(cardsEl, e.clientY);
        if (insertBeforeCard === tgt) return;
        insertBeforeCard = tgt;
        cleanupDrag();
        const line = el('div', { className: 'drop-line' });
        tgt ? cardsEl.insertBefore(line, tgt) : cardsEl.appendChild(line);
      } else if (stage !== draggedStage) {
        col.classList.add('drop-target');
      }
    });

    col.addEventListener('dragleave', (e) => {
      if (!col.contains(e.relatedTarget)) {
        col.classList.remove('drop-target');
        cleanupDrag();
        insertBeforeCard = undefined;
      }
    });

    col.addEventListener('drop', async (e) => {
      e.preventDefault();
      col.classList.remove('drop-target');
      cleanupDrag();
      const id = e.dataTransfer.getData('text/plain') || dragged?.dataset.id;
      const fromStage = e.dataTransfer.getData('text/x-source-stage') || draggedStage;
      if (!id) return;

      if (stage === '2_backlog' && fromStage === '2_backlog') {
        const draggedEl = dragged || document.querySelector(`.card[data-id="${id}"]`);
        if (draggedEl)
          insertBeforeCard
            ? cardsEl.insertBefore(draggedEl, insertBeforeCard)
            : cardsEl.appendChild(draggedEl);
        const newOrder = [...cardsEl.querySelectorAll('.card')].map((c) => c.dataset.id);
        api('PUT', API_BASE + '/api/stories/backlog/order', { ids: newOrder })
          .then((res) => {
            if (!res.ok) throw new Error('rejected');
          })
          .catch(() => {
            console.warn('[bacon-tracker] failed to sync backlog order - reloading');
            load();
          });
        const byId = Object.fromEntries((data.backlog || []).map((s) => [s.id, s]));
        data.backlog = newOrder.map((i) => byId[i]).filter(Boolean);
        renderNextBar();
      } else if (stage !== fromStage) {
        await moveStory(id, fromStage, stage);
      }
    });

    setupCreateForm(col);
  });
}

// Move a story to another stage - the one path for a drop and for the edit
// form's stage picker. Updates the local stage arrays and re-renders only the
// two affected columns (no full-board refetch). Resolves true on success.
async function moveStory(id, fromStage, stage) {
  try {
    const res = await api('PUT', API_BASE + `/api/stories/${id}/stage`, { stage });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      alert(err.error || 'Failed to move story');
      return false;
    }
  } catch {
    alert('Network error - failed to move story');
    return false;
  }
  const fromKey = STAGE_KEYS[fromStage],
    toKey = STAGE_KEYS[stage];
  const idx = (data[fromKey] || []).findIndex((s) => s.id === id);
  if (idx < 0) {
    await load();
    return true;
  }
  const [story] = data[fromKey].splice(idx, 1);
  story.stage = stage;
  if (story.path) story.path = story.path.replace(`/${fromStage}/`, `/${stage}/`);
  if (toKey === 'done') data.done.unshift(story);
  else if (toKey === 'backlog') data.backlog.push(story);
  else {
    data[toKey].push(story);
    data[toKey].sort(BTLogic.byStoryNumber); // trailing number (matches server, BT-104)
  }
  renderColumn(fromStage);
  renderColumn(stage);
  renderNextBar();
  updateTabCounts();
  return true;
}

function cardAfter(container, y) {
  let best = null,
    bestOffset = -Infinity;
  [...container.querySelectorAll('.card:not(.dragging)')].forEach((c) => {
    const { top, height } = c.getBoundingClientRect();
    const offset = y - (top + height / 2);
    if (offset < 0 && offset > bestOffset) {
      bestOffset = offset;
      best = c;
    }
  });
  return best;
}

function cleanupDrag() {
  document.querySelectorAll('.drop-line').forEach((l) => l.remove());
  document.querySelectorAll('.column').forEach((c) => c.classList.remove('drop-target'));
}

async function revealPath(path) {
  // Match the other mutations: check res.ok and catch network errors, so a
  // failed reveal surfaces instead of an unhandled promise rejection (BT-112).
  try {
    const res = await api('POST', API_BASE + '/api/reveal', { path });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      alert(err.error || 'Failed to reveal the file');
    }
  } catch {
    alert('Network error - failed to reveal the file');
  }
}

function renderNextBar() {
  const bar = document.getElementById('next-bar');
  if (!bar) return;
  const next = data && data.backlog && data.backlog[0];
  if (next) {
    document.getElementById('next-title-text').textContent = next.title;
    bar.style.display = '';
  } else {
    bar.style.display = 'none';
  }
}

function updateTabCounts() {
  if (!data) return;
  document.getElementById('tc-icebox').textContent = (data.icebox || []).length;
  document.getElementById('tc-backlog').textContent = (data.backlog || []).length;
  document.getElementById('tc-started').textContent = (data.started || []).length;
  document.getElementById('tc-done').textContent = (data.done || []).length;
}

// ── Done collapse ─────────────────────────────────────────────────────────

function setupDoneCollapse() {
  const col = document.querySelector('[data-stage="4_done"]');
  const btn = col && col.querySelector('.btn-collapse');
  if (!btn) return;
  if (localStorage.getItem('bt-done-collapsed') === 'true') {
    col.classList.add('collapsed');
    btn.textContent = '+';
    btn.title = 'Expand done';
  }
  btn.addEventListener('click', () => {
    const c = col.classList.toggle('collapsed');
    localStorage.setItem('bt-done-collapsed', String(c));
    btn.textContent = c ? '+' : '−';
    btn.title = c ? 'Expand done' : 'Collapse done';
  });
}

// ── Mobile tabs ───────────────────────────────────────────────────────────

function setupMobileTabs() {
  const isMobile = () => window.innerWidth <= 640;

  function setTab(stage) {
    activeMobileStage = stage;
    localStorage.setItem('bt-mobile-tab', stage);
    document
      .querySelectorAll('.mobile-tab')
      .forEach((t) => t.classList.toggle('active', t.dataset.target === stage));
    document
      .querySelectorAll('.column')
      .forEach((c) => c.classList.toggle('mobile-active', c.dataset.stage === stage));
  }

  function applyLayout() {
    if (isMobile()) setTab(activeMobileStage);
    else document.querySelectorAll('.column').forEach((c) => c.classList.remove('mobile-active'));
  }

  document
    .querySelectorAll('.mobile-tab')
    .forEach((t) => t.addEventListener('click', () => setTab(t.dataset.target)));
  applyLayout();
  window.addEventListener('resize', applyLayout);
}

// ── Rendering ─────────────────────────────────────────────────────────────

function renderBody(story) {
  if (!story.body || !story.body.trim())
    return '<span class="empty-body">no content - click edit to add</span>';
  if (story.type === 'feature')
    return (
      '<pre class="gherkin">' +
      renderGherkin(story.body.trimEnd(), story.subtask_lines || []) +
      '</pre>'
    );
  return renderMarkdown(story.body, story.subtask_lines || []);
}

// Which body lines are subtasks (and their data-idx) comes from the
// server's subtask_lines - the client never re-derives fence rules.
function subtaskOrdinals(subtaskLines) {
  const map = new Map();
  subtaskLines.forEach((ln, i) => map.set(ln, i));
  return map;
}

function renderGherkin(text, subtaskLines) {
  const sRe = /^(\s*)(Feature|Background|Scenario Outline|Scenario|Rule|Examples)(:)(.*)$/;
  const stRe = /^(\s*)(Given|When|Then|And|But)(\s.*)$/;
  const tgRe = /^(\s*)(@\S+.*)$/;
  const cmRe = /^(\s*)(#.*)$/;
  const tbRe = /^(\s*)(\|.*)$/;
  const dsRe = /^(\s*)(""".*)$/;
  const cbRe = /^(\s*)[-*] \[( |x|X)\] (.*)$/;
  const stOrd = subtaskOrdinals(subtaskLines);
  let inDs = false;
  return text
    .split('\n')
    .map((line, i) => {
      let m;
      if (stOrd.has(i) && (m = line.match(cbRe))) {
        const done = m[2] !== ' ';
        return (
          esc(m[1]) +
          `<span class="subtask${done ? ' done' : ''}" data-idx="${stOrd.get(i)}" role="checkbox" tabindex="0" aria-checked="${done}">` +
          `<span class="cb">${done ? '☑' : '☐'}</span> ` +
          esc(m[3]) +
          '</span>'
        );
      }
      if ((m = line.match(dsRe))) {
        inDs = !inDs;
        return esc(m[1]) + '<span class="gh-docstr">' + esc(m[2]) + '</span>';
      }
      if (inDs) return '<span class="gh-docstr">' + esc(line) + '</span>';
      if ((m = line.match(cmRe)))
        return esc(m[1]) + '<span class="gh-comment">' + esc(m[2]) + '</span>';
      if ((m = line.match(tgRe)))
        return esc(m[1]) + '<span class="gh-tag">' + esc(m[2]) + '</span>';
      if ((m = line.match(sRe)))
        return (
          esc(m[1]) +
          '<span class="gh-keyword">' +
          esc(m[2] + m[3]) +
          '</span>' +
          '<span class="gh-title">' +
          esc(m[4]) +
          '</span>'
        );
      if ((m = line.match(stRe)))
        return esc(m[1]) + '<span class="gh-step">' + esc(m[2]) + '</span>' + hParams(esc(m[3]));
      if ((m = line.match(tbRe)))
        return esc(m[1]) + '<span class="gh-table">' + esc(m[2]) + '</span>';
      return esc(line);
    })
    .join('\n');
}

function hParams(s) {
  return s
    .replace(/(&lt;[^&]*&gt;)/g, '<span class="gh-param">$1</span>')
    .replace(/(&#34;[^&]*&#34;)/g, '<span class="gh-param">$1</span>'); // esc() already encoded every quote
}

function renderMarkdown(text, subtaskLines) {
  if (!text) return '';
  const blocks = [],
    inlines = [];
  // Mark the server-addressed subtask lines FIRST (by body-line number),
  // so no later pass - fences included - has to re-derive which lines are
  // toggleable. The item text stays inline for strong/em processing.
  const stOrd = subtaskOrdinals(subtaskLines || []);
  const cbRe = /^(\s*)[-*] \[( |x|X)\] (.*)$/;
  text = text
    .split('\n')
    .map((line, i) => {
      const m = stOrd.has(i) && line.match(cbRe);
      return m ? `\x00S${stOrd.get(i)}:${m[2] === ' ' ? 'o' : 'x'}\x00${m[3]}` : line;
    })
    .join('\n');
  const outLines = [];
  let fenced = null;
  for (const line of text.split('\n')) {
    if (line.trimStart().startsWith('```')) {
      if (fenced === null) {
        fenced = [];
      } else {
        blocks.push(fenced.join('\n').trim());
        outLines.push(`\x00B${blocks.length - 1}\x00`);
        fenced = null;
      }
      continue;
    }
    if (fenced !== null) fenced.push(line);
    else outLines.push(line);
  }
  if (fenced !== null && fenced.length) {
    blocks.push(fenced.join('\n').trim());
    outLines.push(`\x00B${blocks.length - 1}\x00`);
  }
  text = outLines.join('\n');
  text = text.replace(/`([^`\n]+)`/g, (_, c) => {
    inlines.push(c);
    return `\x00I${inlines.length - 1}\x00`;
  });
  text = esc(text);
  text = text.replace(/^### (.+)$/gm, '<h3>$1</h3>');
  text = text.replace(/^## (.+)$/gm, '<h2>$1</h2>');
  text = text.replace(/^# (.+)$/gm, '<h1>$1</h1>');
  text = text.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/\*([^*\n]+)\*/g, '<em>$1</em>');
  text = text.replace(/^\x00S(\d+):(x|o)\x00(.*)$/gm, (_, idx, st, rest) => {
    const done = st === 'x';
    return `<li class="subtask${done ? ' done' : ''}" data-idx="${idx}" role="checkbox" tabindex="0" aria-checked="${done}"><span class="cb">${done ? '☑' : '☐'}</span> ${rest}</li>`;
  });
  text = text.replace(/^[-*] (.+)$/gm, '<li>$1</li>');
  // Re-insert extracted code AFTER the line transforms so fenced content
  // is never rewritten into headings/checkboxes/lists.
  text = text.replace(/\x00B(\d+)\x00/g, (_, i) => `<pre><code>${esc(blocks[+i] ?? '')}</code></pre>`);
  text = text.replace(/\x00I(\d+)\x00/g, (_, i) => `<code>${esc(inlines[+i] ?? '')}</code>`);
  return text
    .split(/\n\n+/)
    .map((p) => {
      p = p.trim();
      if (!p) return '';
      // No list items: pass headings/pre through untouched, wrap the rest in <p>.
      if (!/<li[ >]/.test(p)) {
        if (/^<(h[1-3]|pre)/.test(p)) return p;
        return '<p>' + p.replace(/\n/g, '<br>') + '</p>';
      }
      // Mixed block - group consecutive <li> into a <ul>, keeping non-list
      // lines as their own <p>/heading. A checklist that follows a heading
      // with no blank line still lands in a real <ul>, so the subtask
      // hanging-indent has the list padding it relies on (else the -14px
      // margin pulls the checkbox off the left edge).
      const out = [];
      let li = [],
        txt = [];
      const flushTxt = () => {
        if (txt.length) {
          out.push('<p>' + txt.join('<br>') + '</p>');
          txt = [];
        }
      };
      const flushLi = () => {
        if (li.length) {
          out.push('<ul>' + li.join('') + '</ul>');
          li = [];
        }
      };
      for (const line of p.split('\n')) {
        const t = line.trim();
        if (/^<li[ >]/.test(t)) {
          flushTxt();
          li.push(line);
        } else if (/^<(h[1-3]|pre)/.test(t)) {
          flushTxt();
          flushLi();
          out.push(line);
        } else {
          flushLi();
          txt.push(line);
        }
      }
      flushTxt();
      flushLi();
      return out.join('');
    })
    .join('');
}

function esc(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&#34;');
}

// Flip one checkbox in the local body copy using the server-provided
// body-line address - no fence rules re-derived client-side.
function toggleSubtaskInBody(story, index, done) {
  const ln = (story.subtask_lines || [])[index];
  const lines = (story.body || '').split('\n');
  if (ln == null || lines[ln] == null) return story.body;
  lines[ln] = lines[ln].replace(
    /^(\s*[-*] \[)( |x|X)(\] )/,
    (_, pre, __, post) => pre + (done ? 'x' : ' ') + post
  );
  return lines.join('\n');
}

// ── Lookup & DOM helpers ──────────────────────────────────────────────────

function allStories() {
  return [].concat(data.icebox || [], data.backlog || [], data.started || [], data.done || []);
}
function storyById(id) {
  return allStories().find((s) => s.id === id);
}
function storyExists(id) {
  return !!storyById(id);
}

function flashCard(el) {
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  el.classList.remove('flash');
  void el.offsetWidth; // restart animation
  el.classList.add('flash');
}

function gotoStory(id) {
  let target = document.querySelector(`.card[data-id="${id}"]`);
  if (target) {
    flashCard(target);
    return;
  }
  // Blocking story may be a done card on another page - flip to it.
  const idx = (data.done || []).findIndex((s) => s.id === id);
  if (idx >= 0) {
    donePage = Math.floor(idx / DONE_PER_PAGE) + 1;
    renderDone();
    flashCard(document.querySelector(`.card[data-id="${id}"]`));
  }
}

function el(tag, attrs, children) {
  const node = document.createElement(tag);
  Object.entries(attrs || {}).forEach(([k, v]) => {
    if (k === 'className') node.className = v;
    else if (k === 'style') node.style.cssText = v;
    else node.setAttribute(k, v);
  });
  (Array.isArray(children) ? children : children != null ? [children] : []).forEach((c) => {
    node.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  });
  return node;
}

async function api(method, url, body) {
  return fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

// ── Boot ──────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  setupDropZones();
  setupDoneCollapse();
  setupMobileTabs();
  initTheme();
  document
    .querySelectorAll('.theme-toggle')
    .forEach((b) => b.addEventListener('click', toggleTheme));
  document.getElementById('load-retry').addEventListener('click', load);
  load();
});
