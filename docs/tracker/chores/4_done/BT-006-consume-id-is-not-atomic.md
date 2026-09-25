---
id: BT-006
type: chore
status: done
---

Title: Issue story ids one at a time under a lock

**Description:**
Handing out the next story id read the counter, added one and wrote it back with nothing stopping a second request in between. Two stories created at the same moment, from the board and a rake task for example, could get the same id. Unique sequential ids are the tracker's core promise, so taking the next id now holds an exclusive lock on the counter file. The cost is negligible for a local tool.

**Resources:**
- lib/bacon_tracker.rb
