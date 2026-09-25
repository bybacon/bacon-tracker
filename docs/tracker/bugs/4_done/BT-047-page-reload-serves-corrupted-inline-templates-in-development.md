---
id: BT-047
type: bug
status: done
---

Title: Page reload serves a broken board

**Currently:**
After the first reload of the board, Ingo gets an empty page: no cards
render and the browser console shows a JavaScript syntax error. Every
further reload is the same until the server restarts. It is easy to miss
because the menu bar app restarts the server often, but anyone who keeps
the board open in a tab and reloads it hits it.

**Expected:**
The board loads the same way on every request.

**STEPS TO REPRODUCE:**
1. Start the board with rake "story:server"
2. Open http://localhost:4567 - the board renders
3. Reload the page - the board is empty

**REFERENCE:**
-
