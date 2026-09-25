---
id: BT-061
type: bug
status: done
---

Title: The /tracker command describes the wrong folders and backlog format

**Currently:**
The bundled `/tracker` command tells Jean to create stories in singular
folders such as `feature/1_icebox/`, while the tracker only looks in
`features/`, `bugs/` and `chores/`. Stories Jean creates that way never
appear, and their ids are used up. It also describes backlog lines in a
different shape from the one the tracker writes, so lines Jean adds show up
raw on the dashboard.

**Expected:**
The `/tracker` command describes the same folders and the same backlog line
format the tracker itself uses, so following it exactly just works.

**STEPS TO REPRODUCE:**
1. Ask Jean to create a story by following `/tracker` to the letter
2. The file lands in a singular folder and never appears on the board

**REFERENCE:**
-
