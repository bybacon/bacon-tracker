---
id: BT-126
type: chore
status: done
size: S
---

Title: Record the relationship lint decisions and refresh the testing doc

**Description:**
BT-121 added relationship checks to lint and made choices that will look
arbitrary to anyone reading only the code. A blocker that isn't a story id
counts as an external blocker. Done stories are never flagged. A blocked
story that is already started is reported but does not fail the build. A
decision record lets Ingo recall why. The testing doc had also fallen
behind the suite, which invites someone to add tests that already exist.

**Resources:**
- docs/decisions/
- docs/testing.md
- BT-ADR-0013
- BT-121, BT-123

- [x] A decision record explains the relationship lint rules and where findings point
- [x] The decision index lists the new record
- [x] The testing doc describes the current tests
- [x] The README links to the changelog
