---
id: BT-164
type: chore
status: done
---

Title: Document the docs surface endpoints in api.md

**Description:**
The API reference covers every story endpoint, but the docs surface adds new
ones: reading the docs tree and a page, listing decisions, changing a
decision's status, and a wider reveal. None was covered by a story. Keeping
the API reference complete as these endpoints land means Jean and anyone
scripting against the server can rely on one place to look.

**Resources:**
- docs/api.md
- BT-ADR-0017
- BT-127, BT-136
