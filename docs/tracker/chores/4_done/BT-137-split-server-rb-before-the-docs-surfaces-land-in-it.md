---
id: BT-137
type: chore
status: done
---

Title: Split the server file before the docs pages land in it

**Description:**
The server was one very long file with every page template inline. Under
BT-ADR-0015, the docs browser and the decisions board are served by the same
server, so splitting it became a prerequisite rather than tidying. The
decisions board reuses the story board's column and card styles and the
existing detail overlay, rather than adding its own, so both boards look and
behave alike for Ingo.

**Resources:**
- lib/bacon_tracker/server.rb
- BT-ADR-0015
- BT-070, BT-160
