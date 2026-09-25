---
id: BT-170
type: chore
status: done
---

Title: Untrack the lock file and tidy the changelog

**Description:**
Two small pieces of housekeeping. The empty lock file the tracker uses to
serialise writes was committed to git, where it does not belong. The
changelog had no unreleased entry for the move to the new decision records,
and its unreleased section repeated the same headings several times. Ignoring
the lock file and cleaning up the changelog keeps the repository tidy for
anyone reading it.

**Resources:**
- .gitignore
- CHANGELOG.md
