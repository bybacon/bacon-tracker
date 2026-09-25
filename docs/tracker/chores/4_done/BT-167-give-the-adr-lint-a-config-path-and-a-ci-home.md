---
id: BT-167
type: chore
status: done
---

Title: Give the ADR lint a config path and a CI home

**Description:**
The decision contract depends on a lint that fails a pull request when a
record drifts, but no story could deliver it. The configuration had no setting
for where decisions live, and the continuous integration runs that had the
records checked out did not run the lint. BT-129 needs to add a real
decisions location setting and BT-130 needs to say which build runs the lint;
until both happen the lint cannot start.

**Resources:**
- lib/bacon_tracker.rb
- Rakefile
- .github/workflows/ci.yml, .github/workflows/specs.yml
- BT-ADR-0014
- BT-129, BT-130
