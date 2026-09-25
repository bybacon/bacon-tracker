---
id: BT-100
type: bug
status: done
---

Title: Editing the body of a story with broken frontmatter buries the text in it

**Currently:**
When a Markdown story's frontmatter has no closing `---`, for example after
a merge dropped it, and Ingo edits the body from the detail view, the old
body text is saved inside the frontmatter block. The file can no longer be
read properly after that. Setting a field on the same file is already
refused with a "malformed frontmatter" message.

**Expected:**
A body edit on a story with broken frontmatter is refused with the same
clear message, and the file is left unchanged.

**STEPS TO REPRODUCE:**
1. Create a bug file by hand with a frontmatter block that has no closing
   `---`, followed by body text
2. Edit the body from the story's detail view and save
3. The old body text is now inside the frontmatter

**REFERENCE:**
-
