---
id: BT-088
type: chore
status: done
---

Title: Make the README quickstart runnable as written

**Description:**
The quickstart asked the newcomer to pick any namespace during setup, then
ran its first story command against a fixed namespace. Anyone who chose a
different name failed on the very first hands-on step. It was also unclear
which directory to change into. The quickstart now runs cleanly from top to
bottom, so a new user's first try works.

**Resources:**
- README.md
- bin/tracker-init
