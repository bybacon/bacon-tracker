---
id: BT-155
type: chore
status: done
---

Title: Amend the accepted ADRs for contradictions and unverified claims

**Description:**
Several accepted decision records disagree with each other or claim things
that are not true. One says a proposed record is the only non-final status
while another allows accepted records to move on; one says a folder is
detected with no special cases when something must still map it to its
statuses; others give a wrong id example, leave a lint rule's counting
ambiguous, use short numeric references the contract forbids, or point an
open question at a decision that is already settled. Ingo relies on these
records to remember why things were decided, so each fix is added as a dated
amendment rather than a silent edit.

**Resources:**
- BT-ADR-0011, BT-ADR-0014, BT-ADR-0016, BT-ADR-0017
- Rakefile
- BT-041, BT-131
