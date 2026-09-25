---
id: BT-077
type: bug
status: done
---

Title: Subtasks render with no checkbox and the body text is clipped on the board

**Currently:**
When Ingo expands a story with a subtask checklist on the board, the
subtask lines have no checkbox and their text is cut off at the left edge,
so a file path loses its first characters. Done subtasks are struck through
but still have no checkbox. It happens when the checklist sits directly
under a heading with no blank line in between. Long unbroken text such as
file paths can also push past the card edge.

**Expected:**
Each subtask shows a clickable checkbox and its full text, fully visible
inside the card.

**STEPS TO REPRODUCE:**
1. Put a checklist directly under a heading in a story body, with no blank
   line between them
2. Expand the card on the board
3. The subtasks have no checkbox and their text is cut off on the left

**REFERENCE:**
-
