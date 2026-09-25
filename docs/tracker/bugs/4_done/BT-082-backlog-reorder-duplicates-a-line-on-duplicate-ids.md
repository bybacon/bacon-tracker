---
id: BT-082
type: bug
status: done
---

Title: Reordering the backlog can list a story twice

**Currently:**
If a reorder request names the same story more than once, backlog.md is
written with that story listed twice. Later changes to the backlog keep
both lines, so the duplicate stays until Ingo removes it by hand.

**Expected:**
Each story appears in the backlog at most once, whatever order is sent.

**STEPS TO REPRODUCE:**
1. Send a backlog reorder that lists APP-001, APP-001 and APP-002
2. Open backlog.md - APP-001 is listed twice
3. Make any other backlog change - the duplicate is still there

**REFERENCE:**
- BT-054
