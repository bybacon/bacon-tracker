---
id: BT-108
type: bug
status: done
---

Title: The default story template creates a placeholder subtask

**Currently:**
The Markdown template that `tracker-init` writes contains a real checkbox
line with `...` as its text. Every new bug or chore copies it, so each one
appears on the board with a 0/1 subtask bar before anyone has added a
subtask. Ingo's dashboard totals count these placeholders too. The feature
template already keeps its subtask hint inside a comment.

**Expected:**
A new story has no subtasks until someone adds a real one. The template's
checkbox hint stays inside a comment, as in the feature template.

**STEPS TO REPRODUCE:**
1. Set up a project with `tracker-init`
2. Run rake "story:bug[Crash on save]"
3. The new bug shows a 0/1 subtask bar on the board

**REFERENCE:**
-
