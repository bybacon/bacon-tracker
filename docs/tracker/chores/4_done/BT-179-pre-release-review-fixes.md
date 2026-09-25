---
id: BT-179
type: chore
status: done
---

Title: Pre-release review fixes

**Description:**
Before the public release, the whole project was reviewed the way a newcomer
would meet it: install the built gem, follow the README and use every page.
The test suite was green throughout, yet the review found gaps in safety,
setup, accessibility and documentation. Fixing them means Ingo and Jean, Leonor
on Linux and at the keyboard, and anyone trying the tracker for the first
time get a release that works as the README says.

**Resources:**
- README.md, CHANGELOG.md, CONTRIBUTING.md
- BT-ADR-0001, BT-ADR-0003, BT-ADR-0005, BT-ADR-0015, BT-ADR-0016, BT-ADR-0018

- [x] Rake tasks run from the dashboard home write stories and decisions into the right project
- [x] Rendered markdown is sanitised and the docs browser refuses unsafe links
- [x] Long frontmatter values stay on one line
- [x] The quickstart works as written, and `tracker-init --yes` never prompts
- [x] Changing a decision's status creates a missing status folder, and a record without frontmatter is refused
- [x] Moving a story checks its new status before the file moves
- [x] Reveal and open-in-editor work on macOS, Windows and Linux, with a clear error when nothing can open the file
- [x] The dashboard file is read as UTF-8, configured folders accept `~`, and bracketed blocker lists are read correctly
- [x] `tracker-init` checks namespaces instead of rewriting them, registers the project and ignores the lock file
- [x] The board keeps edits after a failed save, offers a stage picker, deep links and keyboard access throughout
- [x] Dependencies, ignore rules and CI are current, including Ruby 4.0
- [x] Unused tasks and leftover code are removed
- [x] rake "story:next" ignores headings, reinstalling does not duplicate decision tasks, and docs links cannot escape the docs folder
- [x] ADRs are amended for the public release
- [x] The changelog, pull request template, security policy and Code of Conduct are corrected
- [x] The README, docs, contributing guide, demo and `/tracker` command match the code
