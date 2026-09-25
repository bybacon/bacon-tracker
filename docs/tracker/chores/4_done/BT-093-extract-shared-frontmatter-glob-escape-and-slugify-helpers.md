---
id: BT-093
type: chore
status: done
---

Title: Share one implementation for frontmatter, path escaping and slugs

**Description:**
Several small routines were copied across the code, and the copies had
drifted apart. That caused real bugs: one copy of the frontmatter reader
crashed on feature files, and one directory lookup forgot to escape special
characters. Giving each routine a single home fixes both bugs at the root
and stops new ones of the same kind.

**Resources:**
- lib/bacon_tracker.rb
- lib/bacon_tracker/dashboard.rb
- lib/bacon_tracker/server.rb
- BT-078, BT-083

- [x] Story frontmatter is read and written in one place
- [x] Special characters in paths are escaped by one shared helper everywhere
- [x] Titles become file names by one shared rule
- [x] Subtasks are counted in one place
