---
id: BT-158
type: chore
status: done
---

Title: Correct the blocked_by graph and split BT-132

**Description:**
Stories can name several blockers, but each docs story was given only one, so
the board showed work as ready that could not really start. Several features
were missing a blocker they plainly depend on, and review findings described
as blocking in prose were not recorded as blockers at all. BT-132 also mixed
an urgent, ready half with a half that had to wait, so it sat at the top of
the backlog and could never be finished. Setting the full set of blockers and
splitting BT-132 lets Ingo trust what the board says is ready.

**Resources:**
- BT-130, BT-131, BT-135, BT-137, BT-138, BT-139, BT-143, BT-144, BT-145
- BT-132 and its split-off command half, BT-171
- docs/flow.md
