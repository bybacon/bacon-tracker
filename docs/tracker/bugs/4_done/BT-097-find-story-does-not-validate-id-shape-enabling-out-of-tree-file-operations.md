---
id: BT-097
type: bug
status: done
---

Title: A story id containing a path can act on files outside the tracker

**Currently:**
Story commands accept any text as a story id without checking that it
looks like one. An id containing `../` points outside the tracker folder,
so when Jean runs a command such as done, start or delete with a mistyped
or crafted id, it can move or delete a file that isn't a story at all.

**Expected:**
Every command checks that the id has the project's story id shape and
refuses anything else with a clear message. No command ever touches a file
outside the tracker folder.

**STEPS TO REPRODUCE:**
1. Run rake "story:done[../../some-file]"
2. The command looks for and acts on a file outside the tracker folder

**REFERENCE:**
-
