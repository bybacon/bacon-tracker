---
id: BT-017
type: chore
status: done
---

Title: Restore server settings exactly after the error test

**Description:**
The test for server errors changes two web framework settings and then set them back to fixed values, not to whatever they were before. Today those values match, but if the defaults ever change, an unrelated test would start failing in a confusing way. Saving and restoring the original values keeps the test self-contained, and any failure shows up where it belongs.

**Resources:**
- spec/bacon_tracker/server_spec.rb
