---
id: BT-053
type: bug
status: done
---

Title: Two changes at the same moment lose one of them

**Currently:**
When two changes reach the same story or the backlog at nearly the same
time, one of them is silently lost. Ingo ticks two subtasks in quick
succession, or reorders the backlog while a stage move is in progress, or
works in two tabs, and on the next load one change has reverted. Nothing
says it happened.

**Expected:**
Changes that arrive together are applied one after the other, and every
one of them is kept.

**STEPS TO REPRODUCE:**
1. Open a story with at least two open subtasks on the board
2. Tick the first two subtasks as quickly as possible
3. Reload the board - one of the two is unticked again

**REFERENCE:**
-
