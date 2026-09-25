---
id: BT-059
type: bug
status: done
---

Title: Setup ignores a custom dashboard file name

**Currently:**
When Ingo sets up a tracker with a dashboard file of any other name, such
as `--dashboard /work/board.md`, the generated Rakefile still looks for
`dashboard.md`. Every story command then stops with an empty project list,
even though the setup summary says to run exactly those commands.

**Expected:**
The generated Rakefile uses the dashboard file that was named during setup,
and the commands in the summary work straight away.

**STEPS TO REPRODUCE:**
1. Run the setup with `--dashboard /work/board.md`
2. Run one of the story commands from the setup summary
3. The command stops, reporting no projects

**REFERENCE:**
-
