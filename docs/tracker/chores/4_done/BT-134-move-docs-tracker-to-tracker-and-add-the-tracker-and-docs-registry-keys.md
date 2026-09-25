---
id: BT-134
type: chore
status: done
---

Title: Move docs/tracker to tracker and add the tracker and docs registry keys

**Description:**
BT-ADR-0016 makes the tracker and the docs sibling roots of a project, so
the tracker no longer sits inside the docs folder. Each project in the
dashboard's registry can now name its own `tracker:` and `docs:` folders.
They default to `tracker/` and `docs/`, relative to the project. A missing
default folder is ignored quietly, and a wrong explicit path gets a warning.
Setup now writes the next id file straight away so the tracker folder is
always recognisable.

**Resources:**
- lib/bacon_tracker/dashboard.rb
- bin/tracker-init
- BT-ADR-0016
- BT-129, BT-166
