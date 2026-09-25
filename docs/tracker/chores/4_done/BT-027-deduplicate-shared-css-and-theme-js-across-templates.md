---
id: BT-027
type: chore
status: done
---

Title: Share colours and the theme toggle between the board and dashboard

**Description:**
The board and the dashboard each carried their own copy of the colour palette, fonts and light/dark theme switch. The copies had already drifted: the border colour differed between the two pages, and the dashboard lacked part of the theme setup. Sharing one copy keeps both pages looking and behaving the same for Ingo, and fixes the border colour along the way.

**Resources:**
- lib/bacon_tracker/server.rb
