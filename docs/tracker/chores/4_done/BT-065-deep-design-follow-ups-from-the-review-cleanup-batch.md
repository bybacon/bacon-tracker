---
id: BT-065
type: chore
status: done
---

Title: Follow up on the design changes from the review cleanup

**Description:**
BT-064 handled the mechanical cleanup. The remaining review items changed
how the tracker is designed, so they got their own pass. Together they make
the story files and stage directories the single authority, stop the board
from ticking the wrong subtask, and cut repeated file reads and writes. Ingo
gets a board worth trusting, and Jean can edit files by hand without the
tracker drifting.

**Resources:**
- BT-064
- BT-ADR-0006
- BT-ADR-0007

- [x] The server tells the board exactly which line each subtask is on, so ticking always hits the right one
- [x] The backlog order file repairs itself, dropping missing stories and adding unlisted ones
- [x] Lint reports a story whose status disagrees with its stage directory
- [x] Editing several fields of a story reads and writes the file once
- [x] Cards build their edit controls only when opened
- [x] Migrating old stories runs one history lookup instead of one per file
