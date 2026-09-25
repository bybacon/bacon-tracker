---
id: BT-112
type: chore
status: done
---

Title: Keep the board in step with disk during fast clicks and failures

**Description:**
The board updates itself before the server answers. In a handful of small
cases that let it drift from the files on disk with no warning: a double
click, a column redrawn mid-edit, a drag during a refresh, or a request that
failed silently. Each case was minor, but together they could leave Ingo
looking at a board that no longer matched the story files.

**Resources:**
- lib/bacon_tracker/server.rb
- BT-044
- BT-093

- [x] Double-clicking add creates only one story
- [x] An open edit survives another column being redrawn
- [x] Fast or repeated clicks on a subtask tick the right line
- [x] Dragging during a refresh never duplicates a card
- [x] Deleting the last card in a stage shows the empty state
- [x] A failed reveal shows an error
- [x] Jumping to a story on a hidden tab switches to that tab
