---
id: BT-036
type: chore
status: done
---

Title: Install the /tracker command during project setup

**Description:**
The docs and the release checklist said project setup installs the `/tracker` command for Claude Code, but it did not, and the command file was not even part of the gem. Either the docs had to change or the feature had to exist. The gem now ships the command file and setup copies it into place when it is not already there, so Jean can use `/tracker` in any project set up with the tracker.

**Resources:**
- bin/tracker-init
- lib/bacon_tracker/commands/tracker.md
- bacon-tracker.gemspec
- BT-001
