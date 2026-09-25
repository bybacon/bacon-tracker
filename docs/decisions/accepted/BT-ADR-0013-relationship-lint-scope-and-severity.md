---
status: accepted
date: 2026-09-12
stories: [BT-121, BT-123]
---

# Relationship lint: what counts as a reference, what counts as a failure

- Date: 2026-09-12
- Related stories: BT-121, BT-123
- Companion: `docs/flow.md` (why a blocked story in progress is legitimate)

## Status

Accepted

## Context

`blocked_by` and `linked_to` were stored and rendered but never checked, so a
blocker could ship while the story waiting on it kept its stale badge
indefinitely. Two such cases were sitting in this project's own tracker when
the checks were written; one had been stale since August.

Adding the checks was easy - `Core#with_reverse_links` already builds the
graph. Deciding what to report was not. A lint that fires on states which are
normal is worse than no lint: people stop reading it, and it takes the real
findings down with it. Three questions had no obvious answer.

**What is a reference?** `blocked_by: sinatra-5.x` is real usage - BT-024 waited
on an upstream release for months. A dangling-reference check that treats every
value as a story ID declares that corrupt.

**Does a done story still have relationships?** `4_done` is append-only, so
their `blocked_by` entries describe what was true when the work shipped.

**Is a started story with an open blocker broken?** `docs/flow.md` explicitly
calls one story blocked plus one moving a legitimate two-story state, and names
it as the reason the started limit is two rather than one.

## Decision

**Only values matching this namespace's ID shape are references.** Anything else
- an upstream version, another team's ticket - passes unchecked. An ID from a
different namespace reads as external for the same reason: this tracker cannot
resolve it either way, so it must not claim the reference is broken.

**A story in `4_done` is never the subject of a finding.** It remains the
*object* of one: a done blocker is exactly what `stale-blocker` detects.

**Severity is split, and only integrity fails the build.** `stale-blocker`,
`dangling-ref` and `cycle` exit non-zero with the pre-existing findings.
`blocked-started` is reported and exits clean - `Core::RELATIONSHIP_WARNINGS`
is the list, and `story:lint` says out loud that the note is not a failure.

**No auto-fixing.** `backlog.md` self-heals because its membership is derivable
from `2_backlog/`. A stale `blocked_by` is not derivable - removing it discards
what the author meant - so lint reports and a human decides.

**An annotation points at the side that appears in the diff** (BT-123). For
`unlisted` that is the story file rather than `backlog.md`, because the pull
request that forgot the backlog line is the one that added the file. A
duplicate ID annotates both of its files, since a pull request may contain only
one. A finding with no single owning file points at `backlog.md` or `.next-id`
rather than inventing a location, and a path outside `GITHUB_WORKSPACE` is
emitted with no `file=` at all - a wrong anchor would annotate an unrelated
file.

## Consequences

- Blocking on something outside the tracker stays a supported use of the field.
- Lint output does not grow as the tracker matures; a project with a thousand
  done stories reports the same volume as one with ten.
- A relationship recorded on a done story is never revisited. Accepted: the
  record is the point, and `4_done` is not edited.
- `blocked-started` can be ignored indefinitely without going red. Accepted -
  the board already colours over-commitment, and CI is the wrong place to
  enforce a working agreement.
- A stale `blocked_by` still needs a human to clear it. The check names the
  story, the field and the line, so the fix is one edit.
