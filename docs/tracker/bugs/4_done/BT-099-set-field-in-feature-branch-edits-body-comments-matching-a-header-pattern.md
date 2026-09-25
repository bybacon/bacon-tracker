---
id: BT-099
type: bug
status: done
---

Title: Setting a feature's field rewrites a comment in its scenarios

**Currently:**
When a feature file has no size line in its header but one of its
scenarios contains a comment like `# size: TBD`, setting the size from the
board rewrites that scenario comment instead of adding a header line. Ingo
still sees no size on the card, and each retry changes the file without
showing the value.

**Expected:**
Setting a field on a feature changes only the header at the top of the
file, and the new value shows on the board.

**STEPS TO REPRODUCE:**
1. Take a feature file with no size in its header and a `# size: TBD`
   comment in a scenario
2. Set the size to M on the board
3. The scenario comment now reads `# size: M` and the card shows no size

**REFERENCE:**
- BT-093
