---
id: BT-060
type: bug
status: done
---

Title: Story files with Windows line endings break the board

**Currently:**
When a story file has Windows line endings, for example after a checkout
with automatic line-ending conversion, the tracker doesn't recognize its
frontmatter. Ingo sees the raw frontmatter inside the card body, changing
size or assignee fails, and moving the card to another stage leaves the old
status in the file.

**Expected:**
Story files work the same whatever their line endings: the frontmatter is
read, edits succeed and stage moves update the status.

**STEPS TO REPRODUCE:**
1. Convert a story file to Windows line endings
2. Open the board - the frontmatter appears in the card body
3. Drag the card to another stage - the status line in the file is unchanged

**REFERENCE:**
-
