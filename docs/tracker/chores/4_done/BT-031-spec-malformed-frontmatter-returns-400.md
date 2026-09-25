---
id: BT-031
type: chore
status: done
---

Title: Test that a story with broken frontmatter gets a clear error

**Description:**
If a story file's frontmatter block is never closed, editing it from the board should fail with a clear "bad request" error, not a generic server failure. The tracker already behaved that way, but no test held it. A test now edits a story with a broken frontmatter block and checks that the response is a bad request carrying an error message, so Ingo always sees what went wrong.

**Resources:**
- lib/bacon_tracker.rb
- spec/bacon_tracker/server_spec.rb
- docs/story-format.md
