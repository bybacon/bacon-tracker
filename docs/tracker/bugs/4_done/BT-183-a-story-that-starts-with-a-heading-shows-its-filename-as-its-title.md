---
id: BT-183
type: bug
status: done
---

Title: A story that starts with a heading shows its filename as its title

**Currently:**
A story whose title is a heading at the top ("# Acceptance flakes on 2026-08-29 — what the evidence supports") has no Title line.
The board then builds the title from the filename, which keeps only plain letters and digits. The card reads "acceptance flakes 2026 08 29 what the evidence supports and excludes": no dashes, no punctuation, no capitals, no umlauts. The real title shows again just below it as the first line of the story.
About 800 stories across the projects on Ingo's dashboard are written this way, so roughly a third of all cards look mangled.

**Expected:**
A story without a Title line that opens with a heading takes its title from that heading, whatever its level. Only the opening line counts, so a "## Description" section further down is never mistaken for a title. Retitling such a story rewrites the heading. The filename is used only when there is neither. Decision records already work this way.

**STEPS TO REPRODUCE:**
1. Write a story whose first line after the header is "# Fix the Ä-key — today"
2. Open the board
3. The card reads "fix the ae key today"

**REFERENCE:**
BT-180 (titles from the Title line)
