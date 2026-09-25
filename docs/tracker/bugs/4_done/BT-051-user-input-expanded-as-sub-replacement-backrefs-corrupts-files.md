---
id: BT-051
type: bug
status: done
---

Title: Backslash sequences in a title or field corrupt the story file

**Currently:**
When Ingo creates a story whose title contains a backslash sequence such as
`\&`, the saved title line comes out garbled, with text from the template
pasted into it. Setting a field such as blocked by to a value containing
the same kind of sequence duplicates or mangles the frontmatter line.

**Expected:**
Whatever Ingo types lands in the file exactly as typed, backslashes
included.

**STEPS TO REPRODUCE:**
1. On the board, create a story titled `Fix \& stuff`
2. Open the new file: the title line contains template text instead of
   the typed title

**REFERENCE:**
-
