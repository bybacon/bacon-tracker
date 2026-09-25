---
id: BT-153
type: chore
status: done
---

Title: Sweep the broken ADR links left by the rename

**Description:**
Moving the decision records into their new folder and naming scheme left dead
links behind in the reference docs, the contributing guide and the README, and
some stories still cite the old paths. The ADR lint checks record frontmatter,
not links, so nothing flags them. Pointing every link and citation at the new
location keeps the docs usable for anyone reading them, and the ADR
reorganisation cannot be called done while they are broken.

**Resources:**
- docs/vocabulary.md, docs/story-format.md, docs/linting.md
- docs/troubleshooting.md, docs/testing.md
- CONTRIBUTING.md, README.md
- BT-ADR-0014
- BT-131
