---
id: BT-029
type: chore
status: done
---

Title: Keep expected messages out of the test output

**Description:**
A passing test run printed an error with a stack trace, plus several warnings about stories in the wrong stage and a missing backlog file. All of it was expected, since the tests check those failure paths on purpose, but it looked alarming. Output that looks broken on a green run teaches people and Jean to ignore real failures. The tests now capture these messages instead of printing them.

**Resources:**
- spec/spec_helper.rb
- spec/bacon_tracker/core_spec.rb
- spec/bacon_tracker/server_spec.rb
