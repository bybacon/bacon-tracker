---
id: BT-169
type: chore
status: done
---

Title: Keep a minimal ADR index until the docs surface lands

**Description:**
The ADR index file was removed because the folder itself is meant to be the
index, but the page that would show it did not exist yet, and the README
still sent readers to a folder that now looks like five bare status
directories. Rather than restore an index that would drift again, the README
explains the layout, points at the accepted records as the ones in force, and
names the contract and the lint that keep them consistent.

**Resources:**
- README.md
- docs/decisions/
- BT-ADR-0014
- BT-131
