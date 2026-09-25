---
id: BT-014
type: chore
status: done
---

Title: Show the same next id that will actually be issued

**Description:**
With an empty or blank id counter file, the tracker issued id 1 for the first story but reported the next id as 0. The migration task showed that 0 to the person running it, which did not match the id the next story received. Both now treat an empty counter the same way, so the displayed next id is always the one that gets used.

**Resources:**
- lib/bacon_tracker.rb
