---
id: BT-105
type: bug
status: done
---

Title: Story migration misorders ids, doubles frontmatter and skips the backlog

**Currently:**
When Ingo migrates an existing tracker with rake "story:migrate", three
things go wrong. In the usual layout, where the tracker sits in a folder
inside the repository, ids are handed out by file modification time rather
than oldest commit first as promised. A file that already has frontmatter
gets a second block added on top. Backlog files are renamed with their new
ids but backlog.md still lists the old names, so the lint fails straight
away.

**Expected:**
Migration numbers stories oldest commit first, leaves files that already
have frontmatter alone, and updates backlog.md to the new ids.

**STEPS TO REPRODUCE:**
1. In a repository with its tracker in a `tracker` folder, run
   rake "story:migrate"
2. Ids follow file modification time, not commit order
3. Run rake "story:lint" - it reports unlisted backlog stories

**REFERENCE:**
-
