---
id: BT-012
type: chore
status: done
---

Title: Test simple text helpers without a sample project

**Description:**
The tests for turning titles into file names, formatting ids and turning file names back into titles each set up a full temporary project on disk, although none of them touch the filesystem. That made the suite slower and hid what each test was really checking. These tests now run against a minimal configuration, as the project's testing conventions ask.

**Resources:**
- spec/bacon_tracker/core_spec.rb
- docs/testing.md
