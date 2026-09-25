---
id: BT-041
type: chore
status: done
---

Title: Keep the tracker's own stories under version control

**Description:**
The tracker promises stories as plain files in git, yet its own stories and the `/tracker` command lived outside any repository. They had no history, so when the id counter and backlog drifted there was nothing to compare against. Putting the stories under version control and shipping the `/tracker` command inside the gem gives Ingo a diff for every change, whoever made it. The decision is recorded in BT-ADR-0003.

**Resources:**
- lib/bacon_tracker/commands/tracker.md
- BT-ADR-0003
- BT-034
- BT-036
