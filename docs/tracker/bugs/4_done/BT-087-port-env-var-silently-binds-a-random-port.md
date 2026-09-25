---
id: BT-087
type: bug
status: done
---

Title: An invalid PORT starts the board on a random port

**Currently:**
When Jean or Ingo starts the board with a PORT value that isn't a number,
such as `PORT=foo` or a stray space, the server starts anyway on a random
port and announces `http://localhost:0`. The board can't be reached at the
address shown, and there is no error. The dashboard command already refuses
a bad port.

**Expected:**
An invalid PORT stops the command with a clear message, the same way the
dashboard command does.

**STEPS TO REPRODUCE:**
1. Run `PORT=foo rake "story:server"`
2. The banner shows `http://localhost:0` and the board is not reachable

**REFERENCE:**
-
