---
id: BT-184
type: bug
status: icebox
---

Title: An extra-small story loses its size without a word

**Currently:**
Sizes are S, M and L. Creating a story with size XS creates the story, uses up its number, and only then says the size was refused, so Ingo has a new unsized story he did not ask for. A story whose file already says XS shows no size on the board, and the check reports the backlog as clean. 62 stories across 8 projects say XS, and none of them shows a size.

**Expected:**
Either XS is a size like the others, or a size the tracker does not know is refused before anything is created and named by the check, with the story and its line. Creating, editing, showing and checking a story all agree on which sizes exist.

**STEPS TO REPRODUCE:**
1. Run rake "story:chore[Tidy the readme,size=XS]"
2. A new chore exists, followed by "could not set fields: size must be S, M, or L"
3. Put "size: XS" into a story's header and open the board
4. The card shows no size, and rake story:lint says the backlog is clean

**REFERENCE:**
BT-101 (one size rule for create and edit)
