---
name: tracker
description: Manage bacon-tracker stories - create features/ bugs/ chores, move them through workflow, edit fields, delete, check the backlog, and view story content. Use when the user mentions stories, the backlog, creating features/ bugs/ chores, or workflow transitions like commit, start, done, next.
argument-hint: "[new feature|bug|chore <title> [field=value]] [commit|start|done|show <ID>] [edit <ID> <field>=<value>] [delete <ID>] [list [stage]] [next] [lint]"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(find *)
  - Bash(grep *)
  - Bash(ls *)
  - Bash(mv *)
  - Bash(rm *)
  - Bash(rake *)
  - Bash(bundle exec rake *)
---

# /tracker - Bacon Tracker

Manage stories for a project using bacon-tracker. Arguments: `$ARGUMENTS`

---

## Vocabulary - use these words

The work item is a **story** (a file). Never call it a card, ticket, issue, or task. A **card** is only the board's rendering of a story. A **column** is only the board's rendering of a stage. The board is the *tracker board*, not a kanban board.

- **type** - `feature`, `bug`, or `chore`. The directory is the plural.
- **stage** - the directory: `1_icebox`, `2_backlog`, `3_started`, `4_done`. Authoritative. `status:` in frontmatter merely mirrors it and can drift.
- **commit / start / done** - the workflow verbs. `commit` means icebox → backlog, *not* a git commit; say which when both are in play.
- **subtask** - a `- [ ]` line in a body. Not a child story; there is no hierarchy, no epics, no parents.
- **blocked_by / blocks**, **linked_to / linked_from** - you write the first of each pair; the second is derived and never typed.
- Stories are **moved**, never assigned or transitioned. Nothing is closed or resolved - it is **done**, and done is append-only.

There are no sprints, points, priorities, or epics. Position in `backlog.md` is the priority. Full glossary: `docs/vocabulary.md` in the bacon-tracker repo.

---

## Step 1 - find the tracker root

**Dashboard setup.** If the current directory holds a `dashboard.md` (the tracker home - where `tracker-init` installs this command), each `## Heading` in it is a project with a `path:` (the project directory) and a `namespace:`. The stories are in `<path>/tracker`, unless the entry has a `tracker:` key, which is relative to `path:`. Relative paths are relative to `dashboard.md`'s directory. An older entry may point `path:` straight at a tracker directory (one holding `backlog.md` or `.next-id`); use it as is. Pick the project the user named (by title or namespace); if they didn't name one and there's more than one, ask.

**Single project.** Otherwise, search the current repo for a directory containing `backlog.md` and `.next-id`. Common locations, in order: `tracker/` (the convention), then `docs/tracker/` (an older layout, still supported). If not found, tell the user and stop.

Decisions, if the project has them, live in a **separate** tree: `docs/decisions/`, with one directory per status and its own `.next-id`. Never conflate the two - a decision is not a story, and `/tracker` does not manage them.

Once found, set `TRACKER_ROOT` to that path.

**Find the namespace** - from the `namespace:` in `dashboard.md`, or from existing files in `TRACKER_ROOT`:
1. Read the first entry in `backlog.md` - e.g. `- APP-003 implement user auth` → namespace is `APP`
2. Or find any story file - e.g. `find $TRACKER_ROOT -name '[A-Z]*-[0-9]*.md' -o -name '[A-Z]*-[0-9]*.feature' | head -1` → parse the prefix before the first `-[0-9]`

**Prefer the rake tasks.** If a `Rakefile` that loads bacon-tracker is available - next to `dashboard.md` in a dashboard setup, or in the project directory in a single-project setup - run the matching rake task instead of editing files by hand. It allocates IDs under a lock and applies exactly the gem's rules. Run it from the Rakefile's directory, with `NS=<namespace>` in a dashboard setup (a single-project Rakefile needs no `NS`), and always **quote a task that has brackets** - zsh treats `[ ]` as a glob:

| Subcommand | Rake task |
|---|---|
| `new <type> <title> [field=value ...]` | `rake "story:<type>[<title>,field=value,...]"` |
| `commit` / `start` / `done <ID>` | `rake "story:commit[<ID>]"` (and `story:start`, `story:done`) |
| `edit <ID> field=value ...` | `rake "story:edit[<ID>,field=value,...]"` |
| `next` | `rake story:next` |
| `lint` | `rake story:lint` |

Rake splits bracket arguments on commas, so a title or value containing a comma can't go through rake - fall back to the file steps below for that one (or set the title afterwards). Prefix with `bundle exec` if the Rakefile's directory has a `Gemfile`. If rake fails, relay its message; don't retry by hand-editing unless the user asks. The file steps below are the fallback when no Rakefile is available, and the only way for `show`, `list`, `delete`, and multi-line body edits.

---

## Step 2 - dispatch on arguments

Parse the first word of `$ARGUMENTS` as the subcommand. Match case-insensitively.

---

### No arguments - status

Show a compact overview by reading the filesystem directly:
- Count files matching `<NS>-*.{md,feature}` in each of `features/`, `bugs/`, `chores/` × `1_icebox/`, `2_backlog/`, `3_started/`, `4_done/`
- Read `backlog.md` for the ordered backlog IDs and titles

Output format:
```
<Project> (<NS>)

  done     12
  started   1
  backlog   3
  icebox    5

  next: APP-003 - implement user auth

  backlog:
    APP-003  implement user auth
    APP-007  add email notifications
    APP-001  set up CI
```

If backlog is empty, say so. If no stories exist at all, suggest `/tracker new feature My First Story`.

---

### `new <type> <title> [field=value ...]`

type must be `feature`, `bug`, or `chore`. The title is everything after the type, except for any trailing `field=value` tokens (`size=`, `assignee=`, `blocked_by=`, `linked_to=`) - those set fields at creation, the same fields as `edit`. The directory for a type is its PLURAL: feature → `features/`, bug → `bugs/`, chore → `chores/` - these are the only directories the tracker scans.

1. Determine N: read the integer from `$TRACKER_ROOT/.next-id`, then **floor it above the highest `<NS>-NNN` already on disk** (`N = max(read, highest + 1)`). A stale `.next-id` from a merge or hand edit must never reissue an existing ID. When `rake` is available, prefer `rake story:<type>['title',field=…]`, which allocates the ID atomically (with this floor, under a file lock).
2. Write `N+1` back to `.next-id`
3. Pad N to 3 digits: `NNN`
4. Slugify the title: lowercase it, turn each run of characters that aren't `a-z` or `0-9` into a single hyphen, and trim hyphens from both ends. If nothing is left, the slug is `untitled`
5. Extension: `.feature` for features, `.md` for bugs and chores
6. Create `$TRACKER_ROOT/<plural-type>/1_icebox/<NS>-<NNN>-<slug>.<ext>` (e.g. `features/1_icebox/...`). The body is the type's `_template.feature` / `_template.md` if one exists, with the title filled in (`Feature: <title>`, or `Title: <title>` on the first line for `.md`). Write frontmatter **in the file's format**: for `.md`, a YAML block `---` / `id: <NS>-<NNN>` / `type: <type>` / `status: icebox` / `---`; for `.feature`, comment-style header lines `# id: <NS>-<NNN>` / `# type: <type>` / `# status: icebox`. (A `.feature` file is parsed by its `# key:` lines **or** a leading YAML `---` block if one is present - but a file mixes only one style, so match the sibling files in the same tracker rather than introducing the other.)
7. If any `field=value` tokens were given, set them in the frontmatter (same rules as `edit`)
8. Confirm the new ID and file path

If type is missing or unrecognised, list valid types and stop. If title is missing, ask for one.

---

### `commit <ID>`

Move a story from icebox → backlog (committing to do it).

1. Find the file: `find $TRACKER_ROOT -path "*/1_icebox/${ID}-*"`
2. `mv` it to the corresponding `2_backlog/` directory
3. Update `status:` in the frontmatter to `backlog`
4. Append `- <ID> <title>` to `backlog.md`, where the title is the filename slug with hyphens as spaces (bottom = lowest priority, unless user specifies a position)
5. Confirm new stage

---

### `start <ID>`

Move a story from backlog → started (actively working on it).

1. Find the file: `find $TRACKER_ROOT -path "*/2_backlog/${ID}-*"`
2. `mv` it to the corresponding `3_started/` directory
3. Update `status:` in the frontmatter to `started`
4. Remove the ID line from `backlog.md` - it mirrors `2_backlog/` only (`rake story:lint` flags leftovers as phantom)
5. Confirm new stage
6. If > 2 stories are now in started across all types, flag it

---

### `done <ID>`

Mark a story as done.

1. Find the file in any non-done stage (`1_icebox/`, `2_backlog/`, or `3_started/`) - `done` may be called from any stage, matching `rake story:done` / `Core#done` (which only refuse a story already in `4_done/`)
2. `mv` it to the corresponding `4_done/` directory
3. Update `status:` in the frontmatter to `done`
4. Remove the ID line from `backlog.md` if present
5. Confirm

---

### `edit <ID> <field>=<value> [...]`

Update story fields in place. Fields: `title`, `size` (S/M/L), `assignee` (initials), `blocked_by` (comma-separated IDs this story waits on), `linked_to` (comma-separated IDs of related stories - a symmetric "see also"), or free-form body edits described in plain language - including adding or ticking off [subtasks](#subtasks).

1. Find the file: `find $TRACKER_ROOT -name "${ID}-*"`
2. Frontmatter fields: update the existing line, or add it if missing - matching the file's format (comment-style for `.feature`, YAML for `.md`). An empty value (`size=`) removes the line.
3. `title`: re-slugify the new title, `mv` the file to `<ID>-<new-slug>.<ext>` in its current stage directory, and update the story's `backlog.md` line if it has one (keep the `- <ID> <title>` format)
4. Reject values containing newlines - the gem treats these as invalid everywhere
5. Confirm what changed

---

### `delete <ID>`

Delete a story permanently.

1. Find the file: `find $TRACKER_ROOT -name "${ID}-*"`
2. If the story is in `4_done/`, refuse and stop: done is a permanent record, and every bacon-tracker interface refuses to delete it. A regression is a new bug, not a reopened or removed story.
3. Show its ID, title, and stage, and confirm with the user before deleting
4. `rm` the file
5. Remove the story's line from `backlog.md` if present
6. Confirm what was deleted

---

### `show <ID>`

Display a story's content:

1. `find $TRACKER_ROOT -name "${ID}-*"` to locate the file
2. Read it, strip the frontmatter block
3. Print: ID, type, stage, title (humanised from filename), any set metadata fields, then body

```
APP-003 - implement user auth
type:       feature    stage: backlog
size:       M
assignee:   AB
blocked by: APP-005
linked to:  APP-012

Feature: Implement User Auth
  ...
```

Omit `size`, `assignee`, `blocked by`, and `linked to` when not set. If the story has subtasks, show its `done/total` count under the metadata.

Those four fields live in the story's own frontmatter. The reverse ends - which stories *this* one blocks, and which link back - aren't stored anywhere; the board derives them across all files. To surface them here, `grep -rl "blocked_by:.*${ID}\|linked_to:.*${ID}" $TRACKER_ROOT` and list the matches as `blocks:` / `linked from:`.

---

### Subtasks

A story tracks its own checklist through Markdown checkbox lines in the **body** - `- [ ]` (open) and `- [x]` (done). They are just body text, so there is no separate command: manage them through `edit`.

- **Add** subtasks: append `- [ ]` lines to the body (via `edit <ID>` with a plain-language body change).
- **Tick off / reopen** a subtask: flip its `- [ ]` ↔ `- [x]` in the body.
- **Count** for `show`/`status`: subtasks are checkbox lines in the body, *excluding* any inside fenced blocks (```` ``` ```` in Markdown, `"""` in Gherkin) - those are examples, not real subtasks. Report `done/total`.

The web UI renders these as clickable checkboxes with a `done/total` bar; from `/tracker` they are ordinary body edits.

---

### `list [stage]`

List stories. Optional stage filter: `icebox`, `backlog`, `started`, or `done`.

Read filenames directly from `$TRACKER_ROOT/{features,bugs,chores}/<stage>/`. Print a compact table:

```
Started (1):
  APP-003  feature  M  AB  implement user auth

Backlog (3):
  APP-007  bug         crash on empty cart
  APP-001  chore       upgrade ruby
  APP-009  feature  S  set up CI
```

Show size and assignee when present in the filename or frontmatter. Default: all stages (done capped at 10 most recent).

---

### `next`

Show the top item from `backlog.md`: read the first ID line, then `show` that story.

---

### `lint`

Check tracker consistency. If a Rakefile with story tasks is available, prefer running `rake story:lint` (with `NS=<namespace>` in a dashboard setup) and relay its output. Otherwise perform the same checks directly on the filesystem:

1. **Backlog drift** - every ID in `backlog.md` must have a file in a `2_backlog/` directory (phantom lines), and every file in `2_backlog/` must have a line in `backlog.md` (unlisted stories)
2. **Duplicate IDs** - no ID may have files in more than one stage directory
3. **Stale `.next-id`** - the counter must exceed the highest existing story number
4. **Status drift** - each story's `status:` frontmatter must match its stage directory (the directory is authoritative)
5. **Stale blocker** - a `blocked_by` naming a story that is now in `4_done`. The blocker shipped and the blocked story never got the memo; clear it from `blocked_by`
6. **Dangling reference** - a `blocked_by` or `linked_to` naming an ID with no story file
7. **Blocker cycle** - `A` waits on `B` waits on `A`, or a story naming itself. Nothing in the cycle can ever start
8. **Started while blocked** - a story in `3_started` with an unresolved blocker. Report it, but this is a flow signal, not corruption: `rake story:lint` deliberately does not fail on it

Checks 5–7 only apply to values shaped like a story ID for this namespace. `blocked_by` may legitimately name something outside the tracker (an upstream release, another team's ticket) - leave those alone. Stories already in `4_done` are never reported as the subject of checks 5–8: done is append-only, so their relationships are record, not a to-do.

Report each finding with the ID and file path, or confirm all checks pass. Don't fix anything without being asked; when asked, the directory is the source of truth.

---

## Implementation notes

- Expand `~` in any paths using shell: `eval echo <path>` or `realpath`.
- When editing frontmatter, match the existing format (comment-style for `.feature`, YAML for `.md`).
- Slugify: `echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'` - and use `untitled` if the result is empty
- `backlog.md` line format: `- <NS>-NNN <title>` (leading dash, single space - exactly what the gem writes; the stats and next-task parsers depend on it). Preserve this when adding/removing entries.
- Keep output concise - one line per story, full content only for `show`.
