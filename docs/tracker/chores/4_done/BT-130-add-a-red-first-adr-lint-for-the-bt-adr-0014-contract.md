---
id: BT-130
type: chore
status: done
blocked_by: BT-129, BT-156
---

Title: Add a red-first ADR lint for the BT-ADR-0014 contract

**Description:**
BT-ADR-0014 sets rules for decision records, and those rules only hold if
something checks them. rake "decision:lint" does, following the same split
as story lint. Broken records fail the build: missing or invalid
frontmatter, a status that disagrees with its directory, duplicate numbers,
supersession links that don't resolve, or a stale next id. Untidy ones are
reported without failing. It was written to fail first against the records
still missing frontmatter, then pass once BT-131 migrated them. It runs in
CI.

**Resources:**
- BT-ADR-0013
- BT-ADR-0014
- docs/decisions/
- .github/workflows/specs.yml
- BT-131, BT-167
