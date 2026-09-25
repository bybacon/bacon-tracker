---
id: BT-068
type: chore
status: done
---

Title: Add the missing lint section to the tracker command

**Description:**
The `/tracker` command advertised a lint action but gave no instructions
for it, so `/tracker lint` left Jean to improvise. The command now runs the
same checks as rake "story:lint": the backlog order file against the
backlog directory, duplicate ids across stages, a stale next id, and status
fields that disagree with their stage.

**Resources:**
- lib/bacon_tracker/commands/tracker.md
- lib/bacon_tracker/tasks.rb
- BT-ADR-0003
