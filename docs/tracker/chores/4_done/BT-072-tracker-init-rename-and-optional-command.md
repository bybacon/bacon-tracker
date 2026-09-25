---
id: BT-072
type: chore
status: done
---

Title: Rename CLI executables to tracker-* and make the /tracker install opt-in

**Description:**
The executables carried a `bacon-` prefix even though the tool is "the
tracker", and setup always installed the `/tracker` command whether it was
wanted or not. The executables are now `tracker-init` and
`tracker-dashboard`, and the command is installed only with `--command`.
Setup says which choice is in effect, and the README explains the two setup
modes before the init steps. The old names are gone, so anything that called
them needs updating.

**Resources:**
- bin/tracker-init
- bin/tracker-dashboard
- bacon-tracker.gemspec
- README.md
- BT-ADR-0008
- BT-073
