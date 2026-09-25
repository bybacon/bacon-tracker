---
id: BT-080
type: bug
status: done
---

Title: Saving or ticking a subtask can fail with a bare server error

**Currently:**
When Ingo saves an edit or ticks a subtask on a story that was deleted a
moment earlier from another tab, or on a hand-made file whose name doesn't
carry a normal story id, the board gets a bare "Internal Server Error"
instead of a message saying what went wrong.

**Expected:**
The board reports that the story could not be found or is not valid, with
a clear message, and no server error.

**STEPS TO REPRODUCE:**
1. Create a story file by hand whose name has no valid story id
2. Open it on the board and tick one of its subtasks
3. The request fails with "Internal Server Error"

**REFERENCE:**
- BT-ADR-0005
