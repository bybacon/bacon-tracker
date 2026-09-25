---
id: BT-055
type: bug
status: done
---

Title: One malformed story file takes down the whole board

**Currently:**
If a single story has frontmatter the tracker can't read, such as a
hand-added date like `due: 2026-08-09` or broken YAML, the board and the
menu bar app both go dark with a server error. Nothing points Ingo to the
file that caused it.

**Expected:**
The board and the menu bar app keep working. The unreadable story is still
shown or skipped with a warning naming the file, and date values are
accepted.

**STEPS TO REPRODUCE:**
1. Add `due: 2026-08-09` to any story's frontmatter
2. Open the board - it fails to load and shows a server error

**REFERENCE:**
-
