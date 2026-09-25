---
id: BT-050
type: bug
status: done
---

Title: Editing title and body together loses the new title

**Currently:**
When Ingo changes both the title and the body of a card in one edit and
saves, the file is renamed to match the new title, but the title line inside
the file still shows the old one. The board and the file now disagree about
what the story is called.

**Expected:**
After a combined edit, both the filename and the title line inside the file
carry the new title, along with the new body.

**STEPS TO REPRODUCE:**
1. Open a card's editor on the board
2. Change the title and the body, then save
3. The file has a new name, but its Title or Feature line is the old title

**REFERENCE:**
-
