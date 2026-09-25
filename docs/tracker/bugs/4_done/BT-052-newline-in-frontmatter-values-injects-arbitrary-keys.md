---
id: BT-052
type: bug
status: done
---

Title: A newline in a field value adds extra frontmatter keys

**Currently:**
Size, assignee and blocked by values are written into the story file as
given, newlines included. A value such as an assignee of "AB", a newline,
then "status: done" adds a second status line to the frontmatter, and the
story reports itself done while it sits in the started stage. A title with
a newline can break the backlog file the same way.

**Expected:**
Values and titles containing a newline are refused with a clear error, and
the file is left unchanged.

**STEPS TO REPRODUCE:**
1. Send an update for a started story with the assignee set to "AB",
   a newline, and "status: done"
2. The frontmatter now has two status lines and the story reads as done

**REFERENCE:**
- BT-063
