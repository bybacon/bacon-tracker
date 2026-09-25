---
id: BT-095
type: chore
status: done
---

Title: Handle unusual titles, case-only renames and byte-order marks

**Description:**
A few unusual inputs broke story files. A title made only of accents,
non-Latin letters or punctuation produced an empty file name and a blank
card. On macOS, renaming a story so that only its letter case changed could
overwrite another file. A file saved with a byte-order mark lost its
frontmatter. Handling these cases keeps Ingo's stories safe whatever gets
typed or whichever editor saved the file.

**Resources:**
- lib/bacon_tracker.rb

- [x] Titles without plain letters or digits still get a usable file name and board title
- [x] Renames that differ only in letter case never overwrite another story
- [x] Files starting with a byte-order mark keep their frontmatter
- [x] Setting a field to an empty value never writes a half-empty line
