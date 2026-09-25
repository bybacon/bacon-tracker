---
id: BT-156
type: chore
status: done
---

Title: Add a docs and decisions fixture to with_fixture_repo

**Description:**
The shared test fixture only builds a tracker tree. The ADR lint, status
changes for decisions and all the docs features need a repository that also
has a docs tree with a decisions folder, its status directories, a template,
an id counter and a proposed list. Adding that as an option, without changing
what existing tests get, lets this work start test-first.

**Resources:**
- spec/spec_helper.rb
- Precedes BT-130
