---
id: BT-090
type: chore
status: done
---

Title: Ship the README and docs in the gem and add its project links

**Description:**
The packaged gem left out the README and the docs folder. Its rubygems.org
page rendered bare, the installed gem had no usage docs, and the README's
links to the docs led nowhere outside GitHub. The gem also listed no source,
changelog or issue links and did not require multi-factor authentication to
publish. Including the docs and project links gives anyone who finds the
gem a complete picture.

**Resources:**
- bacon-tracker.gemspec

- [x] The gem includes the README, changelog and docs
- [x] The gem page links to the source, changelog, docs and issue tracker
- [x] Publishing requires multi-factor authentication
