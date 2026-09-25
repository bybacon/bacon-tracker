---
id: BT-102
type: bug
status: done
---

Title: A done story can be dragged back and reopened

**Currently:**
`docs/flow.md` says done stories are never reopened: a problem found later
gets a new bug with a new id. But Ingo can drag a done card back to any
column on the board, and the move is accepted. The story's status changes
and it reappears in the backlog, rewriting the permanent record.

**Expected:**
Moving a story out of done is refused, on the board and everywhere else,
with a message suggesting a new bug instead.

**STEPS TO REPRODUCE:**
1. Drag a done card back to Started on the board
2. The move is accepted and the story is open again

**REFERENCE:**
- docs/flow.md
- BT-081
