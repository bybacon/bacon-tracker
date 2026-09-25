---
id: BT-166
type: chore
status: done
---

Title: Sequence the config rename through a gem release

**Description:**
BT-129 assumed renaming a configuration setting was a small change. Projects
that use the tracker install a released version of the gem, not the code on
main, so renaming the setting in their Rakefile before a new version ships
breaks every pull request. The same applies to the new registry keys in
BT-134. Spelling out the order (rename in the gem, release a new version,
update the project's dependency, then its Rakefile) keeps both stories doable
without a broken build.

**Resources:**
- Gemfile, Rakefile
- BT-129, BT-134
