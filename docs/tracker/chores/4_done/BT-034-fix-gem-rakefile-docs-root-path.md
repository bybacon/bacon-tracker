---
id: BT-034
type: chore
status: done
---

Title: Point the project's own rake tasks at its real tracker

**Description:**
The tracker's own repository pointed its rake tasks at a folder that did not exist. Because missing folders are skipped quietly, the lint reported a clean tracker with no stories, and the backlog always looked empty. That is how problems in the tracker's own stories went unnoticed. Pointing the tasks at the real tracker makes the lint guard this project's backlog like any other.

**Resources:**
- Rakefile
- BT-035
- BT-041
