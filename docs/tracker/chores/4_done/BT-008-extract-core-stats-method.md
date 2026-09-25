---
id: BT-008
type: chore
status: done
---

Title: Calculate project stats in one place

**Description:**
The dashboard and the stats endpoint each counted stories per stage, worked out progress and found the next task with their own copy of the same logic. A change to one would silently leave the other behind, and Ingo would see different numbers depending on where Ingo looked. Both now use a single shared calculation, which the existing tests already cover.

**Resources:**
- lib/bacon_tracker/dashboard.rb
- lib/bacon_tracker/server.rb
