---
id: BT-030
type: chore
status: done
---

Title: Save a title and body change in a single write

**Description:**
Every edit from the board sends the title and body together. Changing both wrote the story to its old file, renamed it to match the new title, then wrote it again. Nothing tested a title and body change in one call, so a mistake in that path would go unnoticed. Tests now cover a combined edit, including one that changes every field at once from the board, and the story is written once to its final file name.

**Resources:**
- lib/bacon_tracker.rb
- spec/bacon_tracker/core_spec.rb
- spec/bacon_tracker/server_spec.rb
