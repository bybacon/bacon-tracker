---
id: BT-083
type: bug
status: done
---

Title: A namespace with special characters empties the backlog

**Currently:**
If a project's namespace contains characters such as `[`, `]`, `*` or `?`,
for example after a hand edit of the dashboard file, the tracker can no
longer find the backlog's story files. On the next change, such as a stage
move, it decides every listed story is missing and removes all of them from
backlog.md. Ingo loses the whole backlog order at once.

**Expected:**
Any namespace the tracker accepts works everywhere, and the backlog keeps
every story that exists on disk.

**STEPS TO REPRODUCE:**
1. Set a project's namespace to `B[T]` in the dashboard file
2. Move any card to another stage on the board
3. backlog.md is now empty

**REFERENCE:**
- BT-025
- BT-093
