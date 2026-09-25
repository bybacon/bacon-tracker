---
id: BT-013
type: chore
status: done
---

Title: Test that reveal refuses paths outside the project

**Description:**
The reveal-in-Finder endpoint only opens paths inside a tracked docs folder. It is the one security check in the server, and nothing tested it, so a later change could remove it unnoticed. Tests now cover a path inside the project, a path outside it, and a request with no path at all.

**Resources:**
- lib/bacon_tracker/server.rb
- spec/bacon_tracker/server_spec.rb
