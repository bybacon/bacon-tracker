---
id: BT-016
type: chore
status: done
---

Title: Test project stats edge cases and the server error shape

**Description:**
A few behaviours had no tests: an empty project should report zero progress rather than fail, a project with an empty backlog should report no next task, and an unexpected server error should return a plain JSON error message. Without tests, any of these could regress quietly. Covering them keeps the dashboard and the menu bar app reliable on new or quiet projects.

**Resources:**
- spec/bacon_tracker/core_spec.rb
- spec/bacon_tracker/server_spec.rb
