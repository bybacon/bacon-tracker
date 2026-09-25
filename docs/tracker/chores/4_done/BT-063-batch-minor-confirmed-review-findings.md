---
id: BT-063
type: chore
status: done
---

Title: Fix the batch of minor confirmed review findings

**Description:**
A code review confirmed a set of small correctness problems, each too minor
for its own story but together worth one pass. Odd request bodies caused
server errors, some paths and namespaces broke the board, and several board
interactions left stale state on screen. Fixing them together makes the
server and board behave predictably for Ingo and gives Jean clear errors
from the API.

**Resources:**
- lib/bacon_tracker/server.rb
- lib/bacon_tracker.rb
- docs/api.md
- BT-047, BT-052

- [x] Request bodies that aren't JSON objects get a clear 400 instead of a server error
- [x] Special characters in the tracker path no longer empty the board
- [x] Dashboard paths resolve relative to the dashboard file
- [x] A percent sign in the namespace no longer breaks story ids
- [x] Stories sort by number once ids pass 999
- [x] Single-project mode answers only its own routes and returns the same stats fields as the dashboard
- [x] Changing a story's status never touches its body text
- [x] The "next" bar, Done pagination and backlog drop indicator stay current after edits
- [x] The create form shows an error when saving fails
- [x] The API docs list every endpoint and field the server returns
