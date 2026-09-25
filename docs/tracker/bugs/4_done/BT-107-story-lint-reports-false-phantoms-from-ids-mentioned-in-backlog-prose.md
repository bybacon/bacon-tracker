---
id: BT-107
type: bug
status: done
---

Title: Lint reports false phantoms for ids mentioned in backlog notes

**Currently:**
When backlog.md has a heading or comment that merely mentions a story id,
such as a note that a story moved to done, the lint counts it as a backlog
entry. If that story isn't in the backlog folder, rake "story:lint"
reports it as a phantom and fails, even though the tracker is consistent.
Jean then stops to chase a problem that doesn't exist.

**Expected:**
Only real story entries in backlog.md count as backlog members. Notes and
headings that mention an id are left alone by the lint.

**STEPS TO REPRODUCE:**
1. Add a comment mentioning a done story's id to backlog.md
2. Run rake "story:lint"
3. It reports that id as a phantom and fails

**REFERENCE:**
- BT-039
