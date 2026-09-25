---
id: BT-085
type: bug
status: done
---

Title: Other projects' files and other websites can reach a project's board

**Currently:**
On the dashboard, the "reveal in Finder" action on one project's board
accepts a file from any other project. Worse, any web page Ingo visits can
quietly send requests to the board running on localhost and create, move or
delete stories, or reveal files, without Ingo noticing. The risk is low for
a single local user, but it should be closed before the public release.

**Expected:**
Reveal only works for files in the project whose board made the request.
Changes are accepted only when they come from the board itself, not from
another website.

**STEPS TO REPRODUCE:**
1. Start the dashboard with two projects
2. On project A's board, ask to reveal a file from project B - it opens
3. From an unrelated web page, send a request to create a story at
   http://localhost:4567/api/stories - the story is created

**REFERENCE:**
- BT-013
