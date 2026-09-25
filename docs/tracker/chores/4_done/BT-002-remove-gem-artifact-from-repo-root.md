---
id: BT-002
type: chore
status: done
---

Title: Remove the stale gem build from the repository root

**Description:**
An old built gem file sits at the root of the repository. It was never committed, but it clutters the working tree and could be mistaken for a release. Every release builds the gem fresh from its version tag, so the leftover file has no use.

**Resources:**
- .gitignore
- docs/releasing.md
