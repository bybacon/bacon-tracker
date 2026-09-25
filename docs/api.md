# HTTP API

The server exposes a JSON API consumed by the web UI. It binds to localhost only. In **single-project mode** routes are at the paths below. In **dashboard mode** every project route is prefixed with `/projects/:slug` (see [the prefix table](#dashboard-mode-route-prefixes)); only `GET /api/stats` is not.

Request bodies are JSON objects. IDs in the examples use the namespace `APP`.

## Stories

### `GET /api/stories`

Returns all stories grouped by stage. `backlog` is ordered by `backlog.md`; `done` is reverse-chronological by ID.

```json
{
  "meta":    { "tracker_root": "/abs/path", "backlog_path": "/abs/path/backlog.md" },
  "icebox":  [ Story ],
  "backlog": [ Story ],
  "started": [ Story ],
  "done":    [ Story ]
}
```

**Story object:**

```json
{
  "id":         "APP-001",
  "type":       "feature",
  "stage":      "2_backlog",
  "path":       "/abs/path/features/2_backlog/APP-001-add-login-page.feature",
  "title":      "add login page",
  "body":       "Feature: Add Login Page\n  Scenario: ...",
  "size":       "M",
  "assignee":   "AB",
  "blocked_by":  ["APP-005"],
  "linked_to":   ["APP-012"],
  "blocks":      ["APP-020"],
  "linked_from": ["APP-030"],
  "decisions":   ["APP-ADR-0003"],
  "subtasks":      { "done": 1, "total": 4 },
  "subtask_lines": [2, 3, 5, 8]
}
```

`title` is the filename slug, humanized; the in-file `Title:`/`Feature:` line is part of `body`. `subtask_lines` holds the body-line numbers (0-based) of the checklist items, in `index` order - clients should render and toggle by these addresses rather than re-deriving which lines are checkboxes.

`size` and `assignee` are `null` when not set; `blocked_by` and `linked_to` are `[]`; `subtasks` and `subtask_lines` are `null` when the body has no checklist. `path` and `meta` carry absolute filesystem paths (used by the reveal buttons) - the server binds to localhost only.

**Derived fields.** `blocked_by` (this story waits on those) and `linked_to` (a symmetric "see also") are stored in the story's own frontmatter and are the only relationship fields you write. A file-based tracker can't update the far side of a pair, so the server derives the reverse ends over the whole board and adds them **read-only**: `blocks` is the inverse of `blocked_by`, `linked_from` the inverse of `linked_to`. `decisions` lists the decision records whose `stories:` key cites this story (`[]` when the project has no decisions). All three are present on this board listing only - single-story responses (`POST`/`PUT`) can't see the whole set, so refetch the board to pick them up.

### `POST /api/stories`

Create a new story. `type` is `feature`, `bug` or `chore`. `stage` defaults to `1_icebox`. `size` is optional.

```json
{ "type": "feature", "title": "Add login page", "stage": "1_icebox", "size": "M" }
```

Response: `201` with the created Story object.

### `PUT /api/stories/:id/stage`

Move a story to a different stage. Valid stages: `1_icebox`, `2_backlog`, `3_started`, `4_done`. A done story cannot leave `4_done` (400).

```json
{ "stage": "3_started" }
```

### `PUT /api/stories/backlog/order`

Reorder the backlog. Rewrites `backlog.md` with the supplied ID order; entries the request didn't mention are kept, at the bottom.

```json
{ "ids": ["APP-003", "APP-001", "APP-007"] }
```

### `PUT /api/stories/:id`

Update story fields. Only keys present in the body are changed. Pass `"size": ""` or `"assignee": ""` to clear those fields; `"blocked_by": []` or `"linked_to": []` to clear those relations. A new `title` renames the file. Responds with the updated Story object (fresh `path`, `subtasks`, and `subtask_lines` after the edit) - but not the derived fields, which only the board listing computes. If the story disappears between the write and the re-read, the response is `404`.

```json
{
  "title":      "New title",
  "body":       "Updated body text",
  "size":       "L",
  "assignee":   "JD",
  "blocked_by": ["APP-005", "APP-006"],
  "linked_to":  ["APP-012"]
}
```

### `PUT /api/stories/:id/subtasks`

Toggle one checklist item in the story body. `index` counts checkbox lines in body order (fenced code blocks and Gherkin docstrings don't count). Returns the new counts.

```json
{ "index": 0, "done": true }
```

Response: `{ "ok": true, "subtasks": { "done": 2, "total": 4 } }`

### `DELETE /api/stories/:id`

Delete a story. Removes the file and cleans up `backlog.md` if the story was in the backlog. Done stories are a permanent record and can't be deleted (400).

### `POST /api/reveal`

Show a tracked file in the platform's file manager: `open -R` on macOS, `explorer.exe /select,` on Windows, and on Linux `xdg-open` on the folder that contains it. Paths outside the project's roots (tracker, docs and decisions) are a 400. When there's no launcher on the system, the response is `501 { "error": "..." }` saying why. No shell is involved; the path is passed straight to the launcher.

```json
{ "path": "/abs/path/features/2_backlog/APP-001-add-login-page.feature" }
```

Response: `{ "ok": true }`

## Stats

### `GET /api/stats`

Returns project stats. Dashboard mode returns an array with one entry per project, where `name` is the project title from `dashboard.md`. Single-project mode returns a single-element array with the story counts only; its `name` is the **namespace** (there is no separate title) and its `slug` is `null` (no per-project board to link to).

Example (dashboard mode):

```json
[
  {
    "name":         "My App",
    "namespace":    "APP",
    "slug":         "my-app",
    "done":         12,
    "started":      1,
    "backlog":      3,
    "icebox":       5,
    "total":        21,
    "progress_pct": 57,
    "next_task":    "add login page",
    "tracker":      true,
    "docs":         true,
    "pages":        14,
    "decisions":    6,
    "proposed":     2,
    "version":      "1.4.0"
  }
]
```

`tracker` and `docs` say whether each surface exists for the project; `pages`, `decisions` and `proposed` count docs pages, decision records, and records still proposed. `version` is `null` when no VERSION file is found.

## Docs

The docs surface is served at `GET /docs` (dashboard mode: `/projects/:slug/docs`), 404 when the project has none. Every `path` below is relative to the docs root. Where an endpoint takes a path to read or act on (`page`, `editor`, `reveal`), anything the tree would not list - traversal, absolute paths, hidden or `_`-prefixed files, non-page extensions, symlinks that point outside the docs root - is a **400 without content**.

### `GET /api/docs/tree`

The docs tree as nested `{ name, type: "dir"|"page", path, children }` nodes (pages have no `children`) - the same visibility the browser shows: `.md`, `.markdown` and `.txt` pages only, dot- and `_`-prefixed files invisible, the decisions directory's machinery (`proposed.md`, `.next-id`, `_template.md`) hidden while its records list, a tracker tree inside the docs tree omitted, and folders with nothing renderable omitted entirely. The decisions directory's node carries `"decisions": true`; the browser opens the decisions board for it.

### `GET /api/docs/page?path=guides/setup.md`

One page: `{ path, title, content, frontmatter, html }`. `content` is the raw file; `title` is its first `#` heading (or the filename); `frontmatter` is a leading YAML block parsed into an object of strings (`{}` when there is none); `html` is the rendered body. Markdown is rendered as GitHub-flavoured Markdown and **sanitised**: raw HTML, `{::nomarkdown}` blocks, event-handler and `style` attributes, and links or images whose scheme is not `http`, `https` or `mailto` are dropped, and task-list items render as disabled checkboxes. `.txt` pages are escaped into a `<pre>`.

### `GET /api/docs/search?q=append-only`

Case-insensitive full-text search over the pages the tree lists plus the decision records - hidden files are never searched. Returns `[{ path, folder, lineno, line }]`, capped at 3 hits per file and 100 total. A blank query returns `[]`.

### `GET /api/docs/recent`

The most recently changed visible pages, newest first, **from git history rather than mtime** - a checkout touches every mtime without anything having changed. `[{ path, at, date }]`, capped at 20; a docs tree with no repository is `[]`, never an error.

### `GET /api/docs/backlinks?path=guides/setup.md`

What links here: every visible page whose relative markdown links resolve to the target, plus - when the target is a decision record - every page citing its id. `[{ path }]`.

### `GET /api/docs/front`

The project's identity files: `{ readme_html, changelog_html, version, version_ambiguous }`, each `null` when the file is absent (`{}` when no project root is configured). The HTML is sanitised as for `page`. VERSION is found in a fixed order - `./VERSION`, then `*/VERSION` one level deep - unless the registry entry sets `version:` (or the Rakefile sets `version_path`), which overrides the search. Two candidates and no override reports them in `version_ambiguous` instead of guessing.

### `POST /api/docs/editor` · `POST /api/docs/reveal`

Body `{ "path": "guides/setup.md" }`, with the **same scope check as the page read** - anything the tree would not list is a 400 before the filesystem is touched. `editor` opens a page with `$BACON_EDITOR` when it is set (split like a shell command line, so `code -w` works), otherwise the system default: `open` on macOS, `start` on Windows, `xdg-open` on Linux. `reveal` works as [`POST /api/reveal`](#post-apireveal) does and also accepts a folder. Both fire and forget: `{ "ok": true }`, or `501 { "error": "..." }` when there's no launcher on the system.

## Decisions

The decisions board is served at `GET /docs/decisions` (dashboard mode: `/projects/:slug/docs/decisions`), 404 when the project has no decisions directory.

### `GET /api/decisions`

One entry per record: `{ id, status, title, date, supersedes, superseded_by, stories, canonical, docs_path }`. Proposed records come first, in `proposed.md` order, then the rest by id. `title` comes from the record's `#` heading (records keep no title key, so the two cannot drift). `supersedes`, `superseded_by` and `stories` are arrays of ids. `docs_path` is the record's docs-root-relative path when it is reachable through the docs surface, `null` otherwise.

### `POST /api/decisions`

Body `{ "title": "Choose a queue" }` creates a proposed record from `_template.md` - next id from the counter, today's date and the title stamped over the placeholders, `proposed.md` updated - and returns `{ "ok": true, "path": "APP-ADR-0007-choose-a-queue.md" }` (the new file's name). A blank title is a 400. The Rake form is `rake "decision:new[Choose a queue]"`.

### `PUT /api/decisions/proposed/order`

Body `{ "ids": [...] }` reorders `proposed.md` the way the backlog order endpoint reorders `backlog.md`: lines that aren't entries keep their place, the given order applies to the entries the client knew about, and ones it did not know about survive at the bottom rather than being deleted.

### `PUT /api/decisions/:id/status`

Moves a decision forward: `proposed` → `accepted` or `rejected`, `accepted` → `deprecated` or `superseded`. Nothing returns to `proposed`, and `rejected`, `deprecated` and `superseded` are final.

```json
{ "status": "superseded", "superseded_by": "APP-ADR-0010" }
```

`superseded_by` is required when (and only when) the status is `superseded`. A target in the same namespace gets its `supersedes:` side written in the same locked operation; a missing or unknown target is a **400 with neither record touched**, never a partial write. A record without a frontmatter block can't be transitioned (400). Setting the status a record already has is a no-op.

Response:

```json
{ "id": "APP-ADR-0009", "status": "superseded", "external": [] }
```

`external` lists a superseding id from another namespace whose reciprocal side was **not** written - this checkout cannot edit another repository, so record the `supersedes:` half there. `accepted`/`rejected` also set the record's `date` to today; `deprecated`/`superseded` leave it alone.

## Error responses

Errors are JSON `{ "error": "..." }`:

| Status | When |
|---|---|
| `400` | Invalid input: unknown stage or status, unknown ID, a path out of scope, `Invalid JSON body`, or `JSON body must be an object` |
| `403` | A `POST`/`PUT`/`DELETE` whose `Origin` header is not localhost (`cross-origin request rejected`), or a request whose `Host` is not `localhost`, `127.0.0.1` or `::1` (that one is Sinatra's host check and is not JSON) |
| `404` | `Project not found` (an unknown slug in dashboard mode, or a `/projects/...` path in single-project mode), or a story that vanished during `PUT /api/stories/:id` |
| `413` | `request body too large` - bodies are capped at 1 MB |
| `501` | No launcher for reveal or open-in-editor on this system |
| `500` | `Internal Server Error` - details go to the server's stderr, not the response |

## Dashboard-mode route prefixes

```
GET    /projects/my-app                          # the board
GET    /projects/my-app/api/stories
POST   /projects/my-app/api/stories
PUT    /projects/my-app/api/stories/:id/stage
PUT    /projects/my-app/api/stories/:id/subtasks
PUT    /projects/my-app/api/stories/backlog/order
PUT    /projects/my-app/api/stories/:id
DELETE /projects/my-app/api/stories/:id
POST   /projects/my-app/api/reveal
GET    /projects/my-app/docs                     # the docs browser
GET    /projects/my-app/api/docs/tree
GET    /projects/my-app/api/docs/page?path=...
GET    /projects/my-app/api/docs/search?q=...
GET    /projects/my-app/api/docs/recent
GET    /projects/my-app/api/docs/backlinks?path=...
GET    /projects/my-app/api/docs/front
POST   /projects/my-app/api/docs/editor
POST   /projects/my-app/api/docs/reveal
GET    /projects/my-app/docs/decisions           # the decisions board
GET    /projects/my-app/api/decisions
POST   /projects/my-app/api/decisions
PUT    /projects/my-app/api/decisions/proposed/order
PUT    /projects/my-app/api/decisions/:id/status
```

`GET /api/stats` is not prefixed - it always returns all projects in dashboard mode.
