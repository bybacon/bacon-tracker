---
id: BT-044
type: chore
status: done
---

Title: Make board load and reorder failures visible

**Description:**
If the board could not load its stories, for example while the server restarted, it simply stayed empty with no explanation. A backlog reorder the server rejected was ignored, so the board and the backlog file disagreed without any sign. And the dashboard only noticed a newly added project after a server restart. Ingo now sees a message with a retry when loading fails, the board reloads after a rejected reorder, and dashboard changes apply without a restart.

**Resources:**
- lib/bacon_tracker/server.rb
- lib/bacon_tracker/dashboard.rb
