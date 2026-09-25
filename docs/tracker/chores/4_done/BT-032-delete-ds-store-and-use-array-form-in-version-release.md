---
id: BT-032
type: chore
status: done
---

Title: Tidy the library folder and make release git calls safer

**Description:**
Stray macOS Finder files sat in the library folder. They were ignored by git and never shipped, but cluttered the working tree. Separately, the release task built its git tag and push commands as a single string. The version number made that harmless in practice, but passing each argument separately is the safer habit the rest of the code already follows.

**Resources:**
- lib/bacon_tracker/tasks.rb
