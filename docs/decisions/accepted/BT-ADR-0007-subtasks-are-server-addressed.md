---
status: accepted
date: 2026-08-16
stories: [BT-045, BT-065]
---

# Subtasks are server-addressed by body-line index, not re-derived on the client

- Date: 2026-08-16
- Related stories: BT-045, BT-065

## Status

Accepted

## Context

A subtask is a Markdown checkbox line (`- [ ]` / `- [x]`) in a story body. The
board renders them as clickable checkboxes and toggles one by rewriting its line.
Deciding *which* body lines are subtasks is not trivial: checkbox lines inside
fenced blocks (```` ``` ```` in Markdown, `"""` in Gherkin) are examples, not
subtasks, and must be skipped.

If more than one interface derives that rule - the board's JavaScript to render
and toggle, the server to count - the derivations drift. The board's idea of
"subtask #2" can disagree with the server's, so a toggle rewrites the wrong line
(the BT-049 bug class).

Options considered:
1. Each interface derives the subtask lines itself, kept in parity by discipline.
2. Derive the addresses once on the server; the client toggles by address.

## Decision

Option 2. `parse_story_file` computes `subtask_lines` - the fence-aware, 0-based
body-line indices of the real subtasks, in order - and every Story object carries
it. The board renders and toggles **by those addresses**; it never re-parses the
body to find subtasks. `PUT /api/stories/:id` returns the updated Story
(including fresh `subtask_lines`) so the client stays correctly addressed after an
edit without a refetch.

## Consequences

- One implementation of the fence/indent rule (Ruby); the drift class is closed
  by design, not patched.
- Toggling is "flip the line at address N," which is unambiguous.
- The client depends on the server's addressing staying valid, so any mutation
  that renumbers body lines must return the new Story - a client holding stale
  addresses would toggle the wrong line.
- Any new consumer of subtasks reads `subtask_lines`; it does not re-scan the body.
