---
status: accepted
date: 2026-08-08
stories: [BT-041]
---

# Version the parent workspace as its own repo and bundle the /tracker command in the gem

- Date: 2026-08-08
- Related chore: BT-041

## Status

Accepted

## Context

The parent workspace directory (`tracker/`) - the BT tracker state in `docs/tracker`,
`CLAUDE.md`, `.claude/commands/tracker.md`, and the design assets - was not
under version control. A review identified this as the root cause
of silent tracker-state corruption (stale `.next-id`, phantom backlog line):
with no history there was nothing to diff or bisect. Separately, the `/tracker`
slash command lived only in the parent workspace, so the gem could not ship it to users
(BT-036 resolved the false "bundled" claim by deleting it).

Options considered:
1. Make the parent workspace a git repo; leave the `/tracker` command there only
2. Move `docs/tracker` and the `/tracker` command into the `bacon-tracker` gem repo
3. Both: the parent workspace becomes a repo for tracker state/docs/design, and the gem
   gets its own copy of the `/tracker` command to install via `bacon-init`

Option 2 was rejected because the BT tracker is product-wide - it holds stories
for the Swift menu app (`bacon-tracker-menu`, its own repo) as well as the gem -
so it belongs above both child repos, not inside one of them.

## Decision

Option 3. The parent workspace is now a git repo (child repos are gitignored and keep
their own remotes), which makes tracker state, Claude config, and design assets
diffable and recoverable. The `/tracker` command is bundled in the gem at
`lib/bacon_tracker/commands/tracker.md` and installed by `bacon-init` into
`.claude/commands/tracker.md` next to the dashboard, guarded by
`File.exist?` so user edits are never clobbered.

The gem's copy is canonical. The parent repo's `.claude/commands/tracker.md` is an
installed instance of it.

> **Amended (BT-ADR-0008, BT-072):** the installer executable was renamed
> `bacon-init` → `tracker-init`, and the `/tracker` command install is now
> **opt-in** - it is written only when `tracker-init --command` is passed, not
> unconditionally. The `File.exist?` guard against clobbering user edits stands.

## Consequences

- Easier: tracker state has history; `/tracker` actually reaches gem users, as
  BT-036 originally intended; BT-001's publish checklist caveat is resolved.
- Harder: two copies of `tracker.md` exist. Edits must land in the gem copy
  first and be re-synced to the parent repo - accepted because the file changes
  rarely and the gem copy is unambiguously the source of truth.
- The "run `rake story:lint` in CI" idea from BT-034 can now live in the
  parent repo, since that is where the tracker state is versioned.

## Amendment - 2026-09-25 (BT-179)

At the 1.0.0 public release the project's own tracker state lives in this
repository at `docs/tracker/`, and the repository's `Rakefile` points there.
The parent-workspace arrangement described above is historical. The bundled
`/tracker` command stands as decided.

References to `CLAUDE.md` in this and other records mean a maintainer-local
file that is not part of the published repository; the invariants it held are
stated in `CONTRIBUTING.md` and in the records themselves.
