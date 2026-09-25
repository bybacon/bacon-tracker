---
id: BT-163
type: chore
status: done
---

Title: Align the decision template with the contract

**Description:**
The decision template is what people copy, but it disagreed with the contract
it implements. It shipped empty lists for fields the contract says to leave
out, missed one field the contract names, and hardcoded a "related chores"
line when records link to any kind of story. Shipping only the required
fields, with the optional ones commented out, means a new record starts out
valid.

**Resources:**
- docs/decisions/_template.md
- BT-ADR-0014
