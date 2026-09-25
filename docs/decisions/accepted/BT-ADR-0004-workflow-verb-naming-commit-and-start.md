---
status: accepted
date: 2026-08-16
stories: [BT-071]
---

# Workflow verbs: `commit` (icebox → backlog) and `start` (backlog → started)

- Date: 2026-08-16
- Related story: BT-071

## Status

Accepted

## Context

A story moves through four stages - icebox → backlog → started → done - and each
transition needs a verb, exposed identically on the rake tasks, the `/tracker`
command, and `Core`. Two forces shape the naming:

- The icebox is cheap; the backlog is a commitment ("the backlog is a promise",
  `flow.md`). Moving a story from icebox to backlog is the act of deciding to do
  it - not the start of the work.
- A verb that maps to exactly one stage should echo that stage, so the command
  and the directory it produces line up.

## Decision

- `commit` - icebox → backlog. Names the act of commitment.
- `start` - backlog → started. Names beginning the work, and lands the story in
  `3_started/`, so the verb echoes the directory.
- `done` - → `4_done/`, completing the fourth transition.

Verbs are chosen for the act they perform and, where they map to a single stage,
to echo that stage's name - not for interchangeable English synonyms.

## Consequences

- The verb and the directory that share a name agree: `start` → `3_started/`.
- The naming carries the model's opinion in the imperative: you `commit` before
  you `start`, which is the icebox-is-cheap / backlog-is-a-promise distinction
  made operational.
- Seeing why `commit` (not `start`) is the icebox → backlog move requires the
  flow's framing; this ADR and `flow.md` are that framing.
