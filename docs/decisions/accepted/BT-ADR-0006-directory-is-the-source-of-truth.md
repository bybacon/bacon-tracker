---
status: accepted
date: 2026-08-16
stories: [BT-065]
---

# The stage directory is the source of truth; backlog.md and status: derive from it

- Date: 2026-08-16
- Related story: BT-065

## Status

Accepted

## Context

A story's stage is encoded in more than one place: the directory it sits in
(`1_icebox/`…`4_done/`), the `status:` frontmatter field inside the file, and -
for backlog members - a line in `backlog.md`. These move independently: files are
relocated by hand, by `git mv`, by the web UI, or by a merge; `backlog.md` is
hand-editable; `status:` can lag. Multiple representations of one fact drift, so
one of them has to be the authority the others reconcile to.

Options considered:
1. Make one representation canonical and derive the others from it.
2. Keep all three independent and add a reconcile command users must remember to run.

## Decision

Option 1: **the directory is authoritative.** Everything else derives from where
the file actually is.

- `backlog.md` membership derives from `2_backlog/`. Mutation paths (under the
  write lock) drop lines whose file is gone and append lines for files that
  aren't listed, so external edits converge.
- `story:lint` *reports* any `status:` that disagrees with the stage directory
  (exiting non-zero) but does not rewrite it - the directory wins, so the fix is
  to move or re-save the file. Frontmatter `status:` is only rewritten as a side
  effect of an actual stage move (`set_stage`), not by lint.
- `backlog.md` stays human-editable for *ordering* (position = priority); only
  membership self-heals.

## Consequences

- Moving a file - by any tool - is a complete, correct operation; the bookkeeping
  catches up on the next mutation or lint. No manual sync step.
- Corruption is self-limiting rather than compounding.
- `backlog.md` ordering is the one thing not derivable from the directory, so it
  is still hand-maintained and can carry stale *order* (not stale membership)
  until edited.
- `status:` is redundant with the directory by design; it exists for files read
  out of context. Any disagreement resolves as "directory wins."
