---
id: BT-022
type: chore
status: done
---

Title: Show an error when a board change fails to save

**Description:**
Saving, deleting, dragging a card to another stage and reordering the backlog all ignored failed requests. If the server refused a change or the network dropped, the board looked as if it had worked, and Ingo only found out on the next reload. The server already returns a clear error message; the board now shows it for every change, the same way the create form already did.

**Resources:**
- lib/bacon_tracker/server.rb
