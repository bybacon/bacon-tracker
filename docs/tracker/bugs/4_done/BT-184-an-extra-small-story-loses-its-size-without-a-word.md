---
id: BT-184
type: bug
status: done
---

Title: An extra-small story loses its size without a word

**Currently:**
Sizes are S, M and L. Creating a story with size XS creates the story, uses up its number, and only then says the size was refused, so Ingo has a new unsized story he did not ask for. A story whose file already says XS shows no size on the board, and the check reports the backlog as clean. 62 stories across 8 projects say XS, and none of them shows a size.

**Expected:**
The sizes are S, M and L. A size the tracker does not know is refused
before anything is created, so no number is spent and no unsized story
appears. Creating, editing, showing and checking a story all agree on
which sizes exist.

The check names a story whose file already carries a size it does not
know, with the story and its line, as a warning rather than a failure.
The old XS stories were an oversight. They stay as they are, nobody
sweeps them, and the tracker just refuses new ones.

**STEPS TO REPRODUCE:**
1. Run rake "story:chore[Tidy the readme,size=XS]"
2. A new chore exists, followed by "could not set fields: size must be S, M, or L"
3. Put "size: XS" into a story's header and open the board
4. The card shows no size, and rake story:lint says the backlog is clean

**REFERENCE:**
BT-101 (one size rule for create and edit)
