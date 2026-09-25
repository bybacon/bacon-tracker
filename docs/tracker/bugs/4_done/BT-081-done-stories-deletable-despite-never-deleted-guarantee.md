---
id: BT-081
type: bug
status: done
---

Title: Done stories can be deleted from the board

**Currently:**
The README promises that done stories are a permanent record and are never
deleted, and the `/tracker` command tells Jean to refuse to delete them.
But the board's delete button removes a done story without any objection,
so Ingo can lose history with one click.

**Expected:**
Deleting a done story is refused, on the board and everywhere else, with a
clear message.

**STEPS TO REPRODUCE:**
1. Open a done story on the board
2. Click delete
3. The story file is removed with no warning

**REFERENCE:**
- README.md
