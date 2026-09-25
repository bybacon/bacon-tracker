---
id: BT-157
type: chore
status: done
---

Title: Scaffold the decisions structure in tracker-init

**Description:**
`tracker-init` sets up story folders and templates but no decisions folder, so
a new project has nowhere to keep decision records until someone builds the
structure by hand. Scaffolding the status directories, template, id counter
and proposed list alongside the tracker means the decision contract applies
from the first day. It stays optional, like installing the `/tracker` command.

**Resources:**
- bin/tracker-init
- BT-ADR-0008
- BT-134
