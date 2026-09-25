---
id: BT-049
type: bug
status: done
---

Title: Clicking a subtask on the board ticks a different one

**Currently:**
The board and the story file disagree about which lines are subtasks. When
a story has an indented subtask, Ingo clicks one checkbox and a different
line gets ticked in the file. Checkboxes written inside a code block show
up as clickable subtasks, and after that, clicking a real subtask fails.
A code block that is never closed makes the two sides disagree even more.

**Expected:**
The board shows exactly the subtasks the file has, and clicking one ticks
that line and no other.

**STEPS TO REPRODUCE:**
1. Give a story three subtasks, the middle one indented under the first
2. Open the story on the board and click the last subtask
3. The indented subtask is ticked in the file instead

**REFERENCE:**
- BT-064
