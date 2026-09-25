---
id: BT-039
type: chore
status: done
---

Title: Match backlog lines by exact story id

**Description:**
Removing or renaming a story in the backlog found its line by looking for the id anywhere in the text. Once ids reach four digits, removing APP-100 would also remove APP-1000, and a story whose title mentions another id would lose its line when that other story finished. Matching only the id at the start of each line, as backlog reordering already did, keeps the backlog intact. Tests cover both cases.

**Resources:**
- lib/bacon_tracker.rb
- spec/bacon_tracker/core_spec.rb
