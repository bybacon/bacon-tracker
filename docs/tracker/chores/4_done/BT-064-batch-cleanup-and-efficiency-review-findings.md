---
id: BT-064
type: chore
status: done
---

Title: Clean up duplication and wasted work found in review

**Description:**
A code review found the same logic written several times over, with some
copies already drifting apart, and places where the board and the menu bar
app did far more work than needed. This pass removes the duplicates and the
waste so that fixes land in one place and the board stays quick. Changes
that reshape the design were split out to BT-065.

**Resources:**
- lib/bacon_tracker.rb
- lib/bacon_tracker/server.rb
- lib/bacon_tracker/dashboard.rb
- BT-065

- [x] Command-line commands are thin wrappers over one set of operations that report errors the same way
- [x] Story ids are recognised by one shared rule
- [x] One routine edits frontmatter fields
- [x] Stats count stories without reading every file
- [x] Creating or dragging a story refreshes only the affected columns
- [x] Light and dark themes share one definition across pages
