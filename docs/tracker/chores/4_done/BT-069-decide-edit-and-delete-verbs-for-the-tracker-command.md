---
id: BT-069
type: chore
status: done
---

Title: Decide edit and delete verbs for the tracker command

**Description:**
The board can edit story fields and delete stories, but the `/tracker`
command could not. The decision was to add both verbs, because full parity
between interfaces is the product's intent and both actions carry rules
worth getting right every time. Edit keeps the file format intact and
renames the file when the title changes. Delete asks first, tidies the
backlog order, and refuses done stories, since done is a permanent record.
Jean can now do both without a browser.

**Resources:**
- lib/bacon_tracker/commands/tracker.md
- docs/api.md
- docs/flow.md
