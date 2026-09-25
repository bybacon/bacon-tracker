---
id: BT-098
type: bug
status: done
---

Title: Some field values break the frontmatter and wipe the other fields

**Currently:**
When Ingo sets a field to a value containing characters that mean
something in YAML, such as an assignee of "Bob: reviewer", or one starting
with `#` or `[`, the frontmatter can no longer be read. The card stays on
the board but silently loses its size, assignee, blockers and status, and
the lint stops checking it.

**Expected:**
Any value the board accepts is saved so that it reads back exactly as
typed, and the story's other fields stay intact.

**STEPS TO REPRODUCE:**
1. On the board, set a story's assignee to "Bob: reviewer"
2. Reload the board - the card has lost its size, assignee and blockers

**REFERENCE:**
- BT-055
