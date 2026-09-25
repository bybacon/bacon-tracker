---
id: BT-161
type: chore
status: done
---

Title: Mark the superseded sections of the ideas doc

**Description:**
The ideas doc still presents a separate shared gem for docs as decided, with
its own install command and a plan to extract it, although BT-ADR-0015 decided
to keep one gem. The note at the top of the doc is easy to miss, and the doc
is the only place the docs UI is specified, so someone opening it partway
through would build the wrong thing. Marking the old sections superseded in
place and correcting the ones that assume the split keeps it trustworthy.

**Resources:**
- the ideas doc
- BT-ADR-0015
