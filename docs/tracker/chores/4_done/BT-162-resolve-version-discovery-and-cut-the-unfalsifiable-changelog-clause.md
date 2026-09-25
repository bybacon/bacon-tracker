---
id: BT-162
type: chore
status: done
---

Title: Resolve VERSION discovery and cut the unfalsifiable changelog clause

**Description:**
BT-149 expected a project's VERSION file to be found even inside an app
subfolder, but how to search for it was never decided: no order, no depth
limit, no rule for two candidates. It also promised that a very large
changelog would not slow the page down, with no number to test against.
Deciding how VERSION is found, and either measuring the changelog promise or
dropping it, makes the story buildable and its acceptance honest.

**Resources:**
- BT-149
- BT-ADR-0016
- the ideas doc
