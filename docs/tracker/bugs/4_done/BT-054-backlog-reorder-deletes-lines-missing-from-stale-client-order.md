---
id: BT-054
type: bug
status: done
---

Title: Reordering the backlog drops stories the board hasn't seen yet

**Currently:**
When a story is added to the backlog after Ingo loaded the board, from
another tab or by Jean running a rake command, and Ingo then drags cards to
reorder, the new story's line vanishes from backlog.md. Its file stays in
the backlog folder, so the story is no longer listed anywhere.

**Expected:**
Reordering keeps every story in the backlog. Stories the board didn't know
about stay in the list, at the bottom.

**STEPS TO REPRODUCE:**
1. Open the board in a browser tab
2. In the terminal, add a story to the backlog with a rake command
3. Without reloading, drag a card to reorder the backlog
4. The new story's line is gone from backlog.md

**REFERENCE:**
-
