---
status: accepted
date: 2026-08-16
stories: [BT-074, BT-075]
---

# Create and edit share one field=value grammar; no `\n` escaping in Rake args

- Date: 2026-08-16
- Related stories: BT-074, BT-075

## Status

Accepted

## Context

Setting story fields (size, assignee, blocked_by, title, body) should be possible
from every interface - including the Rake CLI - with one grammar rather than a
per-interface syntax. Rake bracket arguments constrain what that grammar can be:
Rake splits them on commas (so `blocked_by=A,B` arrives as two tokens) and its
parser consumes a single backslash (so `\n` becomes a literal `n`). The grammar,
and whether multi-line bodies are reachable, have to live within those limits.

## Decision

One `field=value` grammar, shared by `story:edit` and by the `story:feature|bug|
chore` create tasks (and `/tracker new`), parsed by `Core#edit_assignments`,
which re-stitches a comma-split `blocked_by` back together. `Core#create` creates
the story, then applies the fields through `update_story`, so both paths share one
validator; an invalid field is reported against the just-created ID so it is not
lost.

**No `\n` translation.** Rake's parser consumes a single backslash before `Core`
sees the value, so interpreting `\n` as a newline would silently corrupt input
(`a\nb` → `anb`) rather than help. A rake `body=` therefore sets a single shell
line, with a warning that it replaces the whole body; multi-line bodies and
subtask checklists are the domain of `/tracker`, the web UI, or the editor.

## Consequences

- Create and edit are one grammar and one validation path; learn it once.
- No fragile, version-dependent escape handling to maintain or explain.
- A rake `body=` cannot carry newlines cleanly - an honest limit of shell/Rake
  argument passing, so multi-line editing lives in the other interfaces.
- Do not add `\n` (or similar) escaping to Rake args; the parser will undermine
  it. If multi-line CLI bodies become a real need, take input from STDIN or a file.
