---
id: BT-187
type: bug
status: done
size: S
---

Title: After a page with a code block every docs page and decision fails to load

**Currently:**
Ingo opens a guide that contains a code block, and it shows fine. From then on every other page in the docs browser says "could not load", and so does every decision opened from the decisions board, in every project on the dashboard. The page list, the board columns and the titles still appear, so it looks as if the files were broken, not the tracker. It stays that way until the tracker is restarted, and the next code block breaks it again. It only happens on a machine that has a code highlighting library installed for other reasons, and the tracker never shows highlighted code anyway.

**Expected:**
Every docs page and every decision opens, however many pages with code blocks were opened before. Code blocks look as they do today, plain and unhighlighted. What other software is installed on the machine makes no difference.

**STEPS TO REPRODUCE:**
1. On a machine where the Rouge gem is installed, start the dashboard
2. In the docs browser, open a guide with a fenced code block - it shows
3. Open the decisions board and click any decision - the overlay says "could not load"
4. Go back to the docs browser and open the same guide again - it says "could not load" too

**REFERENCE:**
BT-ADR-0018 (render markdown with kramdown)
