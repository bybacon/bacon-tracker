---
id: BT-025
type: chore
status: done
---

Title: Handle id prefixes with special characters everywhere

**Description:**
Most of the tracker treats a project's id prefix as literal text, but reading the backlog order and detecting a finished migration did not. A prefix with punctuation such as `C++` would quietly give wrong results there, with no error. Every common prefix is plain letters today, but the first unusual one would break the backlog. All of these places now treat the prefix literally, with a test using such a prefix.

**Resources:**
- lib/bacon_tracker.rb
- spec/bacon_tracker/core_spec.rb
