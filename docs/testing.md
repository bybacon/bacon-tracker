# Testing overview

How bacon-tracker is tested, and where to add coverage.

## Running the tests

```bash
bundle exec rspec                 # Ruby suite
node --test spec/js/*.test.js     # JavaScript unit tests (needs Node)
```

CI runs both on every push and pull request (see [`.github/workflows/specs.yml`](../.github/workflows/specs.yml)): the Ruby suite across a Ruby 3.3 / 3.4 / 4.0 × Ubuntu / macOS matrix, and the JS tests on Node 20. The same workflow also lints this repository's own stories (`rake story:lint`) and decision records (`rake decision:lint`).

## Philosophy

- **Behaviour first.** Tests describe behaviour, not implementation. A spec should keep passing through a refactor and fail when behaviour changes.
- **The specs are the documentation.** They're the executable description of how `Core`, the server, and the tasks behave.
- **Don't couple to implementation.** No testing of private methods for their own sake, no over-mocking, no asserting on a stub instead of the behaviour.
- **Assertions must be able to fail.** Prefer specific matchers (a message on a raised error, an exact value) over ones that pass on almost anything.
- **Guard the error boundary.** Web-reachable `Core` methods raise `ArgumentError` (→ HTTP 400); only the Rake wrappers `abort`. Specs assert the right side of that line ([BT-ADR-0005](decisions/accepted/BT-ADR-0005-core-error-handling-boundary.md)).

## The Ruby suite (`spec/`)

| File | Covers |
|---|---|
| `bacon_tracker/core_spec.rb` | `Core` - ID allocation, story creation, workflow verbs, frontmatter parsing (YAML, `.feature` comment style, and YAML-in-`.feature`), backlog operations, title/body/field editing, subtasks, atomic writes, concurrency/corruption guards, relationship findings (stale blocker, dangling ref, cycle, started-while-blocked, and the two exemptions in [BT-ADR-0013](decisions/accepted/BT-ADR-0013-relationship-lint-scope-and-severity.md)), and data-shape edges (BOM, non-UTF-8, empty slug/value). |
| `bacon_tracker/server_spec.rb` | The HTTP API in both single and dashboard mode (rack-test): story CRUD, stage moves, subtasks, reveal (scoped, traversal guards, 501 when there's no launcher), stats, static asset serving, the board and dashboard pages, escaping of story content, and hardening (CSRF Origin check, body cap, security headers, the JSON error handler). Its last block covers `BaconTracker::Launcher`: the reveal/open command per platform, `BACON_EDITOR` splitting, and `Unavailable` when Linux has no `xdg-open`. |
| `bacon_tracker/reveal_scope_spec.rb` | `POST /api/reveal` scope: inside any of the tracker, docs or decisions roots is allowed; outside, traversal, name-prefix siblings, empty paths and unset roots are refused. |
| `bacon_tracker/tasks_spec.rb` | Rake task installation semantics (fresh Rake app per example, no action stacking), `install_for_dashboard` without `NS`, `story:migrate`, and `story:lint` - including which findings fail the build and which only report, both output formats, and the annotation helpers (escaping, and refusing to anchor a path outside the workspace). |
| `bacon_tracker/dashboard_spec.rb` | `Dashboard` parsing - relative paths, slug-collision suffixing, skipping invalid entries, the `tracker:`/`docs:` roots and their defaults, and the older form where `path:` is the tracker directory itself. |
| `bacon_tracker/decision_lint_spec.rb` | `decision:lint`'s findings - failures vs warnings, cross-namespace ids left unchecked - plus the decision counter and `Core#docs_stats`. |
| `bacon_tracker/decision_transitions_spec.rb` | `Core#set_status` (accept, reject, deprecate, supersede, and the forward-only rules), `Core#create_decision`, and `proposed.md` ordering. |
| `bacon_tracker/decisions_api_spec.rb` | `PUT /api/decisions/:id/status` over HTTP, and the `decisions` field on stories in `GET /api/stories`. |
| `bacon_tracker/docs_browser_spec.rb` | The docs surface's `Core` methods and endpoints: tree, page reads and their scope check, Markdown rendering, the decisions board, `POST /api/decisions`, editor/reveal, the front page (README, CHANGELOG, VERSION discovery), search, recently changed, backlinks, and GitHub-style tables. |
| `bacon_tracker/docs_surface_spec.rb` | Serving `/docs` in both modes, and the dashboard cards' links to the board, docs and decisions. |
| `bacon_tracker/pre_release_spec.rb` | Regressions found in the 1.0 pre-release review: `NS=` rake using the server's roots, Markdown sanitising, long and YAML-list frontmatter values, a failed status write leaving the file in place, `story:next` ignoring headings, decision transition edge cases, `~`/relative roots, UTF-8 `dashboard.md` under an ASCII locale, and symlinks out of the docs root. |
| `tracker_init_spec.rb` | `bin/tracker-init` end-to-end (runs the executable in a tmpdir): the opt-in `--command` install, collision abort, confirm prompt, fully non-interactive `--yes`, namespace validation, the `docs/decisions/` scaffold, the registered `path:`, and the gemspec file list. |
| `tracker_dashboard_spec.rb` | `bin/tracker-dashboard` error paths (missing `dashboard.md`, no projects). |
| `spec_helper.rb` | Shared helpers, and a global stub so no spec ever launches a real editor or file manager. |

### The fixture helper

`with_fixture_repo(namespace:, decisions:)` (in `spec_helper.rb`) builds a complete tracker in a tmpdir and yields a configured `Core` and the root. `namespace:` defaults to `TST`; pass `decisions: true` to also scaffold `docs/decisions/` and set `decisions_root`. Use it for anything that touches the filesystem. Pure-function tests (e.g. `#slugify`) don't need a fixture. `write_decision` adds a record to a fixture's decisions tree, and `silence_output` / `silence_errors` capture stdout/stderr for tasks and aborts.

## The JavaScript tests (`spec/js/`)

The browser client lives in [`lib/bacon_tracker/assets/`](../lib/bacon_tracker/assets/): `app.js` (the board), `docs.js` (the docs browser), `decisions.js` (the decisions board), `theme.js`, and `logic.js`. `spec/js/logic.test.js` uses Node's built-in test runner to cover the pure, DOM-free helpers in `logic.js` - story-number sorting (including a namespace that contains digits), docs link resolution and its refusals, supersede candidates, namespace pairing, which link schemes may leave the page, and deep-link hash parsing. CI also runs `node --check` on each asset as a syntax gate.

## Manual testing (the browser UI)

The pages' DOM-heavy behaviour - drag-and-drop, optimistic updates, the detail modal, theming, pagination - isn't unit-tested, so verify it by hand against a running server. The bundled [demo tracker](../examples/demo/) is the quickest target (it's a `git checkout` away from a reset):

```bash
cd examples/demo && bundle exec rake story:server   # → http://localhost:4567
```

The demo has no docs or decisions. For those sections, point a dashboard at this repository, whose `docs/` holds real pages and decision records (run from the repository root):

```bash
printf '## bacon-tracker\npath: %s\nnamespace: BT\ntracker: docs/tracker\n' "$PWD" > /tmp/bt-dashboard.md
bundle exec bin/tracker-dashboard --dashboard /tmp/bt-dashboard.md
```

Then walk this checklist:

**Load & layout**
- [ ] Four columns render (Icebox / Backlog / Started / Done) with the demo's cards in each.
- [ ] The "next" bar shows the top backlog story.
- [ ] Card badges render: type colour, id, size, `done/total` subtask progress, ⛔ blocked-by, ⛔ blocks (amber, derived), 🔗 linked, assignee.
- [ ] A relationship badge that points at a story on the board is clickable and flashes/jumps to it; one pointing at a missing id is greyed with a "(not found)" tooltip.
- [ ] Loading `/#DEMO-004` scrolls to that story and flashes it.

**Drag & drop**
- [ ] Drag a card between columns → it changes stage and the `status:` frontmatter updates (check the file).
- [ ] Drag within Backlog to reorder → `backlog.md` line order changes to match.
- [ ] A rejected drop (e.g. a duplicate-id move) reloads the board rather than lying about the state.

**Create / edit / delete**
- [ ] "+" in a column header opens the inline form; adding a story creates it in the column. A double-clicked "add" does **not** create duplicates.
- [ ] Edit a card → change size / assignee / blocked-by / linked-to / title / body → it saves and re-renders.
- [ ] The edit form's **stage** picker moves the story like a drag; a done story's picker can't move it out of done.
- [ ] A save that fails (stop the server, then click save) shows the error and leaves edit mode open with your changes.
- [ ] After editing blocked-by or linked-to, the board reloads and the reverse badge (⛔ blocks / 🔗) appears on the *other* story too.
- [ ] Delete a story; deleting a **done** story is refused.

**Keyboard**
- [ ] Tab reaches each card's title row; Enter/Space expands and collapses it, and the card's actions appear while it has focus.
- [ ] Tab reaches subtasks; Enter/Space ticks them.
- [ ] On the dashboard, Tab reaches a project card and Enter/Space opens it.

**Detail modal & subtasks**
- [ ] ⤢ opens the detail modal; ✕ / `Esc` / click-outside close it; the board stays put behind.
- [ ] Toggling a subtask checkbox updates the count and writes to the file; a fast double-click does **not** double-toggle.

**Reveal, theme, pagination, mobile**
- [ ] ↗ reveals the file: selected in Finder on macOS, selected in Explorer on Windows, its folder opened on Linux. With no launcher (Linux without `xdg-open`), the board shows the "no launcher found" message rather than a silent no-op.
- [ ] The theme toggle (◐/◑) switches light/dark and persists across a reload.
- [ ] With more than 20 done stories, the Done column paginates.
- [ ] Narrowing the window collapses the columns into mobile tabs.

**Docs and decisions**
- [ ] `/docs` lists the docs tree, renders a page, and search, recently changed and backlinks work.
- [ ] A page containing raw HTML (`<img src=x onerror=alert(1)>`), a `javascript:` link and a task list renders with the HTML and the link dropped and the task list as disabled checkboxes; clicking an in-page link with an unsupported scheme is refused with a notice.
- [ ] Open in editor honours `BACON_EDITOR` (try `BACON_EDITOR="code -w"`).
- [ ] `/docs/decisions` shows records by status; dragging a proposed record reorders `proposed.md`, and dropping on superseded asks for the superseding record.

**Both server modes**
- [ ] Single-project: `rake story:server`.
- [ ] Dashboard: `tracker-dashboard --dashboard dashboard.md` → project cards, click through to a project board, and confirm reveal/stats are scoped to that project.

**Error handling**
- [ ] Stop the server while the board is open → the error bar appears; "retry" recovers once it's back up.

## Adding coverage

- A behaviour change needs a spec in the same PR (it's on the PR checklist).
- New `Core` behaviour → `core_spec.rb`; a new route or response → `server_spec.rb`; a new rake task → `tasks_spec.rb`; docs or decisions behaviour → the matching `docs_*` / `decision*` spec; pure client logic → move it into `logic.js` and add a `spec/js` test.
- Reach for `with_fixture_repo` rather than hand-rolling a tracker directory.
