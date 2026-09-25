---
id: BT-086
type: bug
status: done
---

Title: Odd dashboard entries give an empty namespace or vanish silently

**Currently:**
When a project in the dashboard file has a name made only of symbols, such
as `## +++`, and no namespace of its own, it runs with an empty namespace.
Its stories get file names like `-001` and links between stories misbehave.
A project entry with a typo, such as `paths:` instead of `path:`, simply
disappears from the dashboard, and Ingo gets no warning.

**Expected:**
An entry that would give an empty namespace is refused with a clear
message. An entry missing its path produces a warning naming the project.

**STEPS TO REPRODUCE:**
1. Add a project named `## +++` with only a `path:` line to the dashboard
   file - it runs with an empty namespace
2. Add a project using `paths:` instead of `path:` - it is missing from
   the dashboard, with no warning

**REFERENCE:**
-
