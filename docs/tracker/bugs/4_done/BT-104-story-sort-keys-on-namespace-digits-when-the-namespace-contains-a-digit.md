---
id: BT-104
type: bug
status: done
---

Title: Board columns lose their order when the namespace contains a digit

**Currently:**
When a project's namespace contains a digit, such as `B2B`, `S3` or
`WEB3`, the board sorts stories by that digit instead of by their story
number. Every card looks the same to the sort, so Ingo sees the icebox,
started and done columns in an arbitrary order, and done is no longer
newest first.

**Expected:**
Columns are ordered by story number whatever characters the namespace
contains.

**STEPS TO REPRODUCE:**
1. Configure a project with the namespace `B2B`
2. Create several stories
3. Open the board - the columns are not in story number order

**REFERENCE:**
- BT-086
