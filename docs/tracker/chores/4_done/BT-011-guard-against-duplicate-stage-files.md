---
id: BT-011
type: chore
status: done
---

Title: Lint stories that appear in more than one stage

**Description:**
If the same story id ends up in two stage folders, after a manual file move or an interrupted move, the tracker quietly works on whichever copy it finds first and ignores the other. Edits then land in the wrong file and nobody notices. The lint now reports any id found in more than one stage, so the problem is visible and easy to fix before it causes damage.

**Resources:**
- lib/bacon_tracker.rb
- docs/linting.md
