---
id: BT-092
type: chore
status: done
---

Title: Settle the lock file and make rake a runtime dependency

**Description:**
The lock file was both committed and marked as ignored. It also pinned a
single Mac platform, so contributors on Linux or Intel Macs could hit
install errors. Separately, the gem's main interface is its rake tasks, yet
rake was only a development dependency. That works only while Ruby happens
to bundle rake. Resolving both makes installs predictable for every
contributor and user.

**Resources:**
- .gitignore
- Gemfile.lock
- bacon-tracker.gemspec
- lib/bacon_tracker/tasks.rb
- BT-170

- [x] The lock file is handled one consistent way
- [x] Rake is a runtime dependency of the gem
