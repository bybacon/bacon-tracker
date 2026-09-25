---
id: BT-048
type: bug
status: done
---

Title: Moving a story overwrites a same-named file in the destination stage

**Currently:**
When the same story id ends up in two stages, for example after a git
merge, Ingo moves the card and the copy already sitting in the destination
stage is silently replaced. The duplicate that the lint would have reported
is gone, along with whatever it contained, and there is no error on the
board or in the terminal.

**Expected:**
The move is refused with a clear message when the destination file already
exists. Both copies stay in place so rake "story:lint" can report them.

**STEPS TO REPRODUCE:**
1. Put a copy of story APP-001 in both chores/2_backlog and chores/4_done
2. Drag the backlog card to Done, or run rake "story:done[APP-001]"
3. The copy in 4_done now holds the backlog copy's content, with no error

**REFERENCE:**
-
