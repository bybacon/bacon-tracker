---
id: BT-168
type: chore
status: done
---

Title: Correct the key invariant in the agent instructions and add decisions

**Description:**
The instructions every agent session loads listed only three of the six
operations that must report errors instead of stopping the process, while the
contributing guide and BT-ADR-0005 list all six. They also said nothing about
decision records, so Jean, asked to write an ADR, would produce an invalid
one. Listing all six operations and adding a short paragraph on decisions
fixes both.

**Resources:**
- CONTRIBUTING.md
- BT-ADR-0005, BT-ADR-0014
- BT-113, BT-132
