---
id: BT-114
type: chore
status: done
---

Title: Bring the tracker command's instructions in line with the rake tasks

**Description:**
The `/tracker` command's instructions differed from what the rake tasks
actually do. Following them, Jean could reuse an existing story id after a
merge, or write a new feature file with a header the tracker cannot read.
Jean could also look for a story to finish in too few stages. Aligning the
instructions means the command gives the same result as the rake task.

**Resources:**
- lib/bacon_tracker/commands/tracker.md
- lib/bacon_tracker.rb

- [x] New stories get ids the same safe way the rake tasks issue them
- [x] The instructions spell out the header format for new feature files
- [x] Finishing a story works from any stage except done, as it does in rake
