---
status: accepted
date: 2026-08-16
---

# State is the filesystem in git, not a database

- Date: 2026-08-16
- Companion: `docs/flow.md` (the working-model rationale; this ADR records the technical choice)

## Status

Accepted

## Context

A tracker needs somewhere to keep stories and their state. The default reach is
a database or a hosted service. bacon-tracker instead keeps every story as a
plain file (Gherkin for features, Markdown for bugs/chores) and encodes its
stage as the directory it sits in (`1_icebox/`…`4_done/`). `backlog.md` and
`.next-id` are plain text. There is no database, no server-side persistence, no
third-party service.

Options considered:
1. A datastore (SQLite/hosted) with an export path.
2. Files in the repo as the system of record; stage = directory; moving work =
   moving a file.

## Decision

Option 2. The repository *is* the database. Consequences that follow directly:
stories version and ship with the code in the same commit; history, timing, and
reasoning are recoverable with `git log`/`git blame`; every interface (Rake CLI,
web board, `/tracker`, a text editor) is just a view over the same files and
they reconcile rather than compete. The `Core` class is the whole persistence
layer - filesystem logic, no ORM. See BT-ADR-0006 for why the directory (not a
redundant field) is authoritative, and `flow.md` for the way-of-working this buys.

## Consequences

- Easier: zero infrastructure; `git` provides history, diff, branching, backup,
  and audit for free; project management shows up in code review.
- Easier: offline, portable, and inspectable with standard tools.
- Harder: no cross-repo query engine - reporting across projects is the
  dashboard aggregating `Core` instances, not a SQL query. Very large trackers
  pay filesystem-scan costs a database would index away.
- Harder: concurrent writers need explicit care (see BT-ADR-0011); there is no
  transaction manager.
- Reconsider only if scale or cross-cutting queries outgrow the filesystem -
  and even then, keep files as the system of record and add an index beside it.
