---
id: BT-154
type: chore
status: done
---

Title: Generalize the id and list primitives over a record shape

**Description:**
Decision records are meant to reuse the same id and list handling that stories
use, but that handling only understands stories: three-digit ids, the story id
format, the backlog file and story directories. A decision id like
`BT-ADR-0018` or an entry in the proposed list would not be recognised. Making
id format, width, list file and the next-id floor depend on the kind of record
lets decisions share one implementation instead of a copy. The two ADRs that
assumed this came for free are corrected to say it needed work.

**Resources:**
- lib/bacon_tracker.rb
- BT-ADR-0014, BT-ADR-0015
- Blocks BT-146 and BT-147
