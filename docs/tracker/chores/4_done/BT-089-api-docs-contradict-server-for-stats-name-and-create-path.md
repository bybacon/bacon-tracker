---
id: BT-089
type: chore
status: done
---

Title: Align the API docs with the server on stats name and created stories

**Description:**
The API docs disagreed with the server in two places. The stats example
showed a project title where single-project mode returns the namespace. The
docs also promised that creating a story returns the full story, but the
file path was left out. Without the path, a newly created card's reveal
button did nothing until the page was reloaded. Clients like the menu bar
app and Jean's scripts need the docs and the server to agree.

**Resources:**
- docs/api.md
- lib/bacon_tracker/server.rb

- [x] The stats example shows the value the server actually returns
- [x] Creating a story returns the same fields as reading one
