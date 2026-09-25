---
status: accepted
date: 2026-08-16
---

# Support both a central multi-project dashboard and per-project standalone use

- Date: 2026-08-16
- Related: BT-ADR-0003 (parent-repo-as-repo)

## Status

Accepted

## Context

Two usage shapes exist. A person with one repo wants the tracker to live inside
it and run with no ceremony. A person juggling several repos wants one place to
see and drive all of them. A single-mode tool forces one of these to be awkward.

The building block is `Core`: one configured instance (a `docs_root` + a
`namespace`) manages one project's files. The open question was how many
projects one process spans and where the tracker home lives.

Options considered:
1. Per-project only - a `Rakefile` in each repo; no cross-project view.
2. Central only - every project registered in one dashboard; nothing standalone.
3. Both, over the same `Core` primitive.

## Decision

Option 3, because `Core` already scopes to one project and composing is cheap:

- **Per-project (standalone):** the repo has its own `Rakefile` that configures
  one `Core`; `rake story:*` runs without `NS=`. Nothing central required.
- **Central (recommended):** a `dashboard.md` in a tracker home lists projects
  (`path` + `namespace`); a `Dashboard` wraps one `Core` per entry, and `NS=`
  selects the project for Rake. `tracker-dashboard` serves all of them, each on
  its own board. Story files still live in each project's own repo.

The namespace prefix on IDs (BT-ADR-0011) is what keeps projects distinct in the
central view.

## Consequences

- Easier: the one-repo case stays zero-config; the many-repo case gets a single
  pane without moving anyone's story files out of their repo.
- Easier: one code path - the dashboard is just N `Core`s - so features written
  for one mode work in the other.
- Harder: two setup paths to document and test (README covers both; the server
  specs exercise single and dashboard mode).
- Harder: the central home is a separate thing to version - resolved by making
  the parent repo its own repo (BT-ADR-0003).
