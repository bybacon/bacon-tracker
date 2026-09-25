---
id: BT-132
type: chore
status: done
---

Title: Update the decision-making skill and the tracker command to the new ADR contract

**Description:**
Once BT-ADR-0014 was accepted, the decision-making skill Jean uses still
wrote records in the old format. Every new decision would have failed the
ADR lint. The skill now writes records that follow the contract and uses the
project's own decision template instead of a private copy, so the two can't
drift. The tracker command update moved to BT-171, since it only needed to
change once the tracker directory moved.

**Resources:**
- docs/decisions/_template.md
- lib/bacon_tracker/commands/tracker.md
- BT-ADR-0014
- BT-134, BT-171
