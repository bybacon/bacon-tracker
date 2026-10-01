---
id: BT-180
type: bug
status: done
---

Title: The board shows a story title without its umlauts and dots

**Currently:**
A card's headline drops every letter that is not plain ASCII. A story
called "Datenschutzerklärung" reads "datenschutzerkl rung" on the card,
and "Go-live on bybacon.com" reads "go live on bybacon com", all in lower
case. The body below the headline shows the title correctly, so Ingo sees
two spellings of the same story at once. The edit form starts from the
mangled headline, so saving an unrelated change would write it into the
file.

**Expected:**
The card shows the title the way it was typed, umlauts, dots and capitals
included. Only a story file without a title line falls back to the name
made from its filename.

**STEPS TO REPRODUCE:**
1. Create a chore called "Datenschutzerklärung prüfen"
2. Open the board
3. The card headline reads "datenschutzerkl rung pr fen"

**REFERENCE:**
BT-181, BT-182
