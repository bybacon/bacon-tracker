---
id: BT-136
type: chore
status: done
---

Title: Widen the reveal endpoint to both project roots

**Description:**
Revealing a file in Finder is only allowed inside the project it belongs
to, which stops one project from reaching another's files. Now that a
project has both a tracker root and a docs root, reveal must accept a file
inside either one and still refuse anything outside them. Getting this wrong
would reopen a path-traversal hole closed in BT-085, so it has its own
tests.

**Resources:**
- lib/bacon_tracker/server.rb
- BT-ADR-0016
- BT-085
