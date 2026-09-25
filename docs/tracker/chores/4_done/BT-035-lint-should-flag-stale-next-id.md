---
id: BT-035
type: chore
status: done
---

Title: Lint an id counter that is behind the existing stories

**Description:**
The tracker's id counter was found pointing at a number already used by finished stories, so the next few new stories would have reused existing ids. Nothing in the lint checked for this. The lint now reports when the counter is not higher than every existing story id and says which value it should be, so Jean and Ingo catch the problem before a duplicate id is issued.

**Resources:**
- lib/bacon_tracker.rb
- lib/bacon_tracker/tasks.rb
- docs/linting.md
- BT-034
