---
id: BT-103
type: bug
status: done
---

Title: Adding to a backlog with no final newline glues two entries together

**Currently:**
When backlog.md doesn't end with a newline, which is common after a hand
edit, the next story added to it is glued onto the last line. Jean commits
a story to the backlog and the two entries become one line. The new story
then shows without a title, reorders and removals hit the wrong story, and
a duplicate line for it appears later.

**Expected:**
A new backlog entry always goes on its own line, whether or not the file
ended with a newline.

**STEPS TO REPRODUCE:**
1. Remove the final newline from backlog.md
2. Run rake "story:commit[APP-009]"
3. The last two backlog entries are now on a single line

**REFERENCE:**
-
