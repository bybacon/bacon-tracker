---
id: BT-058
type: bug
status: done
---

Title: Two projects with similar names share one board address

**Currently:**
The dashboard gives each project a web address based on its display name
alone. Two projects named "My App" and "My-App" get the same address, so
when Ingo opens the second project's board shows, and edits, the first
project's stories. Nothing warns that the names clash.

**Expected:**
Every project on the dashboard gets its own unique board address, and each
board shows and changes only its own project's stories.

**STEPS TO REPRODUCE:**
1. List two projects titled "My App" and "My-App" in the dashboard file
2. Start the dashboard and open the second project's board
3. The first project's stories are shown

**REFERENCE:**
-
