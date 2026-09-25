---
id: BT-094
type: chore
status: done
---

Title: Stop repeating directory scans and speed up the backlog sort

**Description:**
The menu bar app asks for stats every few seconds. Each time, the dashboard
rebuilt every project and rescanned all its files. Within one request, the
same directories were also checked many times over. Creating a story
rescanned everything even when the stored next id was fine, and sorting the
backlog slowed down sharply as it grew. Cutting this waste keeps the board
and the menu bar app quick as projects grow.

**Resources:**
- lib/bacon_tracker/dashboard.rb
- lib/bacon_tracker.rb
- lib/bacon_tracker/server.rb

- [x] Project stats are reused until a project's files change
- [x] Stage directories are looked up once per request
- [x] Creating a story rescans only when the next id looks stale
- [x] The backlog sorts in a single pass
