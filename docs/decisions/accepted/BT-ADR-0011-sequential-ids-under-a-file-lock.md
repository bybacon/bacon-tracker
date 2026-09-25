---
status: accepted
date: 2026-08-16
stories: [BT-035]
---

# Story IDs are sequential integers issued from .next-id under a file lock

- Date: 2026-08-16
- Related story: BT-035 (lint flags a stale `.next-id`)

## Status

Accepted

## Context

Every story needs a stable, human-friendly identifier that also sorts in
creation order (so `4_done/` read in ID order is a timeline - see `flow.md`).
Because state is files in git (BT-ADR-0010), ID issuance has no database sequence to
lean on, and multiple writers can create stories at once (a Rake task and the web
UI, or concurrent web requests).

Options considered:
1. Random or hash-based IDs (UUID/slug-hash) - no coordination needed.
2. Timestamps - sortable, but ugly and collision-prone at sub-second rates.
3. A monotonic integer counter persisted in the repo, guarded against races.

## Decision

Option 3. IDs are `NAMESPACE-NNN` - a namespace prefix plus a zero-padded
integer read from `.next-id`. `consume_id` reads, increments, and writes back
`.next-id` while holding an **exclusive `flock` on `.next-id` itself** - that
lock (not the story-file `with_lock`) is what serializes concurrent creators, so
`consume_id` is safe even when called outside `with_lock` (e.g. `story:migrate`).
`create_story` additionally runs it inside `with_lock`. A spec asserts unique IDs
under threaded access. `.next-id` defaults to 1 when missing,
and `story:lint` flags a `.next-id` that has fallen behind the highest existing
ID (BT-035) - the one drift a counter-in-a-file is prone to.

## Consequences

- Easier: IDs are short, memorable, sortable, and creation-ordered; the
  namespace prefix keeps multiple projects distinct in one dashboard (BT-ADR-0012).
- Harder: issuance is a coordinated write, so it must stay under the lock - an
  unlocked increment reintroduces the collision this exists to prevent.
- Harder: `.next-id` is a piece of derived state that can go stale (hand edits,
  merges); lint is the backstop, not a guarantee.
- Merges across branches that each minted IDs can duplicate a number; resolve by
  renaming the loser, since the directory - not the ID - is the real location.

## Amendment - 2026-09-14 (BT-155)

The Consequences say "merges across branches that each minted IDs can duplicate
a number; resolve by renaming the loser." That is no longer true.
`Core#consume_id` floors the counter above the highest id on disk on every read,
so a stale or conflicted `.next-id` issues a **fresh** id rather than a duplicate.
The loser of a merge needs no rename. The preceding bullet still holds: `.next-id`
remains derived state that can go stale, and lint remains the backstop.
