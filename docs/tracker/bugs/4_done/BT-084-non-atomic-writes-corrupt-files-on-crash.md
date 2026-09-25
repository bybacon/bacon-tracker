---
id: BT-084
type: bug
status: done
---

Title: A crash while saving leaves an empty or cut-off file

**Currently:**
When the server is stopped partway through saving, by a crash, a forced
quit, a full disk or the laptop going to sleep, the story file or backlog.md
being written is left empty or cut short. Nothing restores it, so Ingo
finds a damaged story, or a backlog missing its order, the next time the
board opens.

**Expected:**
A save either completes or leaves the previous version of the file intact.
A file is never left half written.

**STEPS TO REPRODUCE:**
1. Start the board and begin saving a large story edit
2. Kill the server process while the save is in progress
3. The story file is empty or cut short

**REFERENCE:**
- BT-079
- BT-103
- BT-ADR-0010
