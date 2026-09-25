---
id: BT-042
type: chore
status: done
---

Title: Share stages and templates between project setup and the library

**Description:**
The project setup command kept its own list of stages and story types and its own copy of the story templates, separate from the library. Adding a stage or changing a template meant changing two places, and the two could drift so that new projects started out of step with the tracker. Setup now takes its stages, types and default templates from the library, so a change is made once.

**Resources:**
- bin/tracker-init
- lib/bacon_tracker.rb
