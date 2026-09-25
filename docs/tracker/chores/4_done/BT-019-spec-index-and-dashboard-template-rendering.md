---
id: BT-019
type: chore
status: done
---

Title: Test that the board and dashboard pages render

**Description:**
The tests only covered the JSON API, so the board and dashboard pages Ingo actually looks at had no coverage at all, including how story titles and bodies are escaped. Request tests now check that the board renders its four stage columns and theme toggle, that the dashboard shows a card per project with its health and counts, that a project page links back to the dashboard, and that an empty dashboard shows its empty state.

**Resources:**
- lib/bacon_tracker/server.rb
- spec/bacon_tracker/server_spec.rb
