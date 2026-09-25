---
id: BT-127
type: chore
status: done
size: M
---

Title: Split the README into reference docs

**Description:**
The README tried to pitch, onboard, specify and serve as a maintainer
runbook all at once. It grew long enough that the part doing the selling got
scrolled past. The story format, linting, troubleshooting and releasing
material now live in their own reference docs. The quickstart, setup,
working model, board and `/tracker` sections stay, so a newcomer can decide,
install and create a first story without leaving the page.

**Resources:**
- README.md
- docs/story-format.md
- docs/linting.md
- docs/troubleshooting.md
- docs/releasing.md
- BT-ADR-0013

- [x] The story format has its own doc, and the README keeps an example and a link
- [x] The linting doc explains every finding, what to do about it, both output formats and CI use
- [x] The troubleshooting doc covers common failures that lint does not catch
- [x] The releasing doc is linked from the contributing guide
- [x] The README is trimmed and every link and anchor still works
