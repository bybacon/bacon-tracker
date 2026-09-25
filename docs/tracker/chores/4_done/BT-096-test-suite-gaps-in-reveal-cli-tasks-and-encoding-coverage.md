---
id: BT-096
type: chore
status: done
---

Title: Close test gaps in reveal, the CLI tools, rake tasks and encoding

**Description:**
Several parts of the tracker had little or no test coverage, so a
regression could ship unnoticed. The reveal test opened a real Finder
window and checked nothing. The dashboard executable had no tests, and most
rake tasks were never exercised. Some tests also depended on the order in
which they ran. Closing these gaps protects the commands Jean relies on
most.

**Resources:**
- spec/bacon_tracker/server_spec.rb
- spec/tracker_init_spec.rb
- spec/bacon_tracker/tasks_spec.rb
- spec/spec_helper.rb
- BT-078

- [x] Reveal is tested without opening Finder, including paths that try to escape the tracker
- [x] The dashboard and setup executables are tested, including invalid input
- [x] Every rake story and version task is exercised
- [x] Tests pass in any order
- [x] Stories that aren't valid UTF-8 are covered
