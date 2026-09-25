---
id: BT-131
type: chore
status: done
blocked_by: BT-130
---

Title: Migrate the gem ADRs to the BT-ADR-0014 contract and seed .next-id and proposed.md

**Description:**
The gem's decision records predated BT-ADR-0014, so they didn't follow its
naming, layout or frontmatter. Every record now has a namespaced name, sits
in the directory for its status, and carries its status and date in
frontmatter, with the body text left unchanged. The status directories, the
template, the next id counter and the proposed list are in place, so new
records start out valid and the ADR lint passes.

**Resources:**
- BT-ADR-0014
- docs/decisions/
- BT-130
