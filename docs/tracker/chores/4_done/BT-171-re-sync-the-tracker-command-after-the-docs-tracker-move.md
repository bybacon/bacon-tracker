---
id: BT-171
type: chore
status: done
---

Title: Re-sync the tracker command after the docs tracker move

**Description:**
The `/tracker` command points at story paths under the old tracker location.
Once BT-134 moves the tracker to the repository root, every one of those
paths is wrong and Jean would look for stories in the wrong place. Updating
the command that ships with the gem, and the copy installed in the project,
keeps them identical and correct. This was split out of BT-132 because it
cannot start before BT-134 lands.

**Resources:**
- lib/bacon_tracker/commands/tracker.md
- BT-ADR-0003
- BT-132, BT-134, BT-158
