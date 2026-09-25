---
id: BT-009
type: chore
status: done
---

Title: Make the progress bar show real completion

**Description:**
The progress figure ignored finished work and simply filled up once ten stories were in flight. A project with a larger backlog showed a bar that was always full, with no explanation and no test behind it. Showing the share of stories that are done tells Ingo something true about each project at a glance.

**Resources:**
- lib/bacon_tracker/dashboard.rb
- lib/bacon_tracker/server.rb
