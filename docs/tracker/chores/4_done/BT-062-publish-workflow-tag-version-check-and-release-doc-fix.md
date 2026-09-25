---
id: BT-062
type: chore
status: done
---

Title: Check the release tag against the gem version before publishing

**Description:**
The publish workflow released whatever version the gem declared on any
version tag, so a tag and a gem version that disagreed could ship a
mislabelled release. The README's release checklist also pointed the
releaser at a version field that doesn't exist. The workflow now stops
unless the tag matches the gem version, and the checklist points at the
version rake tasks, so Ingo can cut a release without second-guessing it.

**Resources:**
- .github/workflows/publish.yml
- lib/bacon_tracker/version.rb
- README.md
- BT-001
