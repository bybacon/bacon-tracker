---
id: BT-028
type: chore
status: done
---

Title: Complete the release tooling

**Description:**
The release checklist asked for a CHANGELOG update, but there was no CHANGELOG. The release docs described `rake version:patch`, `version:minor`, `version:major` and `version:release`, but none of those tasks existed. A macOS Finder file was also committed at the repository root. Adding the CHANGELOG and the version tasks, keeping the version in one place the code can read, and ignoring Finder files makes the documented release steps work as written.

**Resources:**
- docs/releasing.md
- CHANGELOG.md
- lib/bacon_tracker/version.rb
- .gitignore
