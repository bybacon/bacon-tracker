---
id: BT-135
type: chore
status: done
---

Title: Add decision status changes to every interface

**Description:**
Decisions need to move from proposed to accepted, rejected, deprecated or
superseded. Following BT-ADR-0017, that works the same way from the API, the
rake tasks, the `/tracker` command and the board, so Jean and Ingo get the
same rules. Decisions only move forward and never return to proposed.
Superseding a decision updates both records together or not at all, and a
missing target is refused.

**Resources:**
- lib/bacon_tracker.rb
- lib/bacon_tracker/server.rb
- lib/bacon_tracker/tasks.rb
- BT-ADR-0017
- BT-084
