---
id: BT-071
type: chore
status: done
---

Title: Rename workflow verbs so they match the stages

**Description:**
The old verbs were confusing: "start" moved a story from the icebox to the
backlog, and "begin" moved it on to started. The mix-up came up again and
again. Now `commit` moves a story into the backlog and `start` moves it into
started, so each verb means what it says. It is a clean break: the old
`begin` is gone, and old habits fail loudly on the wrong stage instead of
quietly doing the old thing.

**Resources:**
- lib/bacon_tracker.rb
- lib/bacon_tracker/tasks.rb
- lib/bacon_tracker/commands/tracker.md
- README.md
- docs/flow.md
- BT-ADR-0004
