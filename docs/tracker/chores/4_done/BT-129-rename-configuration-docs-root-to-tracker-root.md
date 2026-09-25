---
id: BT-129
type: chore
status: done
---

Title: Rename the docs_root setting to tracker_root

**Description:**
The `docs_root` setting points at the tracker's story directory. Now that
projects also have a real docs root, the old name misleads. It is renamed
outright to `tracker_root`, with no alias, and shipped in a minor release.
Existing Rakefiles must switch to the new name when they upgrade. The same
change adds a `decisions_root` setting for where decision records live,
since they don't always sit beside the stories.

**Resources:**
- lib/bacon_tracker.rb
- BT-ADR-0016
- BT-155, BT-166, BT-167
