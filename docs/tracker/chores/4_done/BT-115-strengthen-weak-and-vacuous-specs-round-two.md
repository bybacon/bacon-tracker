---
id: BT-115
type: chore
status: done
---

Title: Strengthen tests that pass for the wrong reason

**Description:**
Several tests passed without really checking what they claimed. They would
have stayed green through a real regression. Some never touched the running
server, some checked only half of their case, and one changed shared
settings in a way that affected later tests. Tightening them makes the suite
a safety net Ingo and Jean can rely on before shipping.

**Resources:**
- spec/bacon_tracker/server_spec.rb
- spec/bacon_tracker/core_spec.rb
- spec/bacon_tracker/tasks_spec.rb
- BT-101

- [x] Picking up new projects is tested through the running server
- [x] Invalid story sizes are tested, not just missing ones
- [x] Wrong-stage errors are checked by their message
- [x] Story creation times are tested with distinct commits
- [x] Stats tests check that non-zero counts appear
- [x] The script-injection test confirms its setup succeeded
- [x] Tests restore any settings they change
- [x] Finding a story is tested across every stage
