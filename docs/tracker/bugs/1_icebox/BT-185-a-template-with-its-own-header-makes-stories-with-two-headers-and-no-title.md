---
id: BT-185
type: bug
status: icebox
---

Title: A template with its own header makes stories with two headers and no title

**Currently:**
A project's story template can start with its own header block (id, type, status).
A new story made from it then has two headers: the real one and the template's, with a placeholder id like "SOU-000".
The title Ingo typed goes only into the filename.
The card shows the template's placeholder ("The team should be able to [overarching goal]").
The check does not notice either problem.
The chore and bug templates of most of our projects all start this way.

**Expected:**
A new story has exactly one header and the title as typed, whether or not the template starts with a header of its own.
A template whose header would be copied into new stories is pointed out, so the project can drop it.

**STEPS TO REPRODUCE:**
1. Start chores/_template.md with "---", "id: X-000", "type: chore", "---"
2. Run rake "story:chore[Fix the thing]"
3. The new file has two header blocks
4. The card reads "The team should be able to [overarching goal]"

**REFERENCE:**
SUP-194