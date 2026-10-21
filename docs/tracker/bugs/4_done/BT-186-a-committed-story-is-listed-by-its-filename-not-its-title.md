---
id: BT-186
type: bug
status: done
---

Title: A committed story is listed by its filename, not its title

**Currently:**
When Ingo commits a story to the backlog, the new line in backlog.md gets
its title from the filename, not from the story. For a chore filed as
"WTM-087-an_external_check_watches_uptime_kuma.md" the line reads
"WTM-087 an_external_check_watches_uptime_kuma", while the story itself is
titled "The operator should hear about it when Uptime Kuma itself goes
down".

The shared CI check for trackers compares every backlog line with the
story's own title and fails the run with "title does not match". The
local check does not compare titles, so it reports the backlog as clean on
the same tree. Ingo pushes a green tree and gets a red pull request.

Editing a story's title already writes the real title to its backlog line,
so the two ways of getting a line into backlog.md disagree with each other.

**Expected:**
- Committing a story writes the story's own title to backlog.md, the same
  way editing the title does. The name made from the filename is used only
  when the story has no title line.
- The local check reports a backlog line whose title does not match the
  story's title, naming the story, the listed title and the real one, so
  the local check and CI agree on the same tree.

**STEPS TO REPRODUCE:**
1. Create a chore and change its Title line to a full sentence ("The operator should …")
2. Commit it to the backlog
3. backlog.md lists it by its filename, not the sentence
4. Run the local check: "Backlog is clean"
5. Push: the shared conventions job fails with "title does not match"

**REFERENCE:**
Found in WTM PR #184 (2026-10-16), CI run 38953486751. Fixed by hand in the
PR's second commit (ac648da). BT-180 (titles from the Title line) covers the
board; this is the same gap in backlog.md and the check.
