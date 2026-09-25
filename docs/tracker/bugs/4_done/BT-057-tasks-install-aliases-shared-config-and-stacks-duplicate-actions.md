---
id: BT-057
type: bug
status: done
---

Title: A Rakefile with two projects runs every story command twice in the wrong project

**Currently:**
When one Rakefile sets up story tasks for two projects, both sets of tasks
end up pointing at the second project, and each command runs twice. Jean
runs one command to create a feature and gets two new stories, both in the
second project, and none in the first.

**Expected:**
Each project's tasks act on that project only, and one command does its
work once.

**STEPS TO REPRODUCE:**
1. Configure a Rakefile to install story tasks for project A, then for
   project B
2. Run rake "story:feature[Some title]"
3. Two stories are created, both in project B

**REFERENCE:**
-
