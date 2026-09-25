---
id: BT-079
type: bug
status: done
---

Title: The board sometimes loads while a file is half written

**Currently:**
While a card is being moved, edited or reordered, a board load at the same
moment can read a story file or the backlog before it has been fully
written. Ingo occasionally sees an empty board, a story with its body cut
short, or backlog entries missing. Reloading usually brings everything
back, which makes it hard to pin down.

**Expected:**
Every board load sees each file either before a change or after it, never
halfway through.

**STEPS TO REPRODUCE:**
1. Open a board with many stories
2. From another tab or script, move cards between stages over and over
3. Keep reloading the board - now and then it is empty or a story is cut
   short

**REFERENCE:**
- BT-053
- BT-084
