---
id: BT-111
type: bug
status: done
---

Title: tracker-init proceeds on any answer except exactly "n"

**Currently:**
At the "Proceed? [Y/n]" prompt, `tracker-init` only cancels when Ingo
types exactly `n`. Spotting a wrong path and typing `no`, `q`, `quit` or
a stray character still goes ahead. It creates the tracker, adds it to
the dashboard and writes a Rakefile in the place Ingo was trying to reject.

**Expected:**
Any answer starting with `n`, and common words for quitting, cancel setup.
Only `y` or Enter goes ahead.

**STEPS TO REPRODUCE:**
1. Run `tracker-init` and review the confirmation screen
2. Type `no` and press Enter
3. The tracker is created anyway

**REFERENCE:**
-
