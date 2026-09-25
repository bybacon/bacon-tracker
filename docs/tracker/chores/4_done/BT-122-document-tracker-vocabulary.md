---
id: BT-122
type: chore
status: done
size: S
---

Title: Document tracker vocabulary

**Description:**
The project had no glossary, so agents drifted into words like "ticket",
"column" or "card" for things that already have names. A card is only how
the board draws a story, not the work item itself, so the fix is to define
the terms rather than ban words. The glossary covers story, card, type,
stage, the workflow verbs, backlog and icebox, subtasks, and the story
relationships. There are two copies, one for people and a short one inside
the `/tracker` command, so Jean reads the same terms every session.

**Resources:**
- docs/vocabulary.md
- docs/flow.md
- lib/bacon_tracker/commands/tracker.md
- BT-ADR-0004

- [x] A vocabulary doc defines the tracker's terms
- [x] The `/tracker` command carries a short version of the term list
- [x] The README and flow doc link to the vocabulary
- [x] Existing docs were checked for "card" used to mean a story
