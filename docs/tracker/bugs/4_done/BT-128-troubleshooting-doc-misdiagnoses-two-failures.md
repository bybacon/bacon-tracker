---
id: BT-128
type: bug
status: done
size: S
---

Title: Troubleshooting doc misdiagnoses two failures

**Currently:**
`docs/troubleshooting.md` sends readers the wrong way on two failures.
For "Don't know how to build task 'story:lint'" it blames a missing
Rakefile. In a dashboard setup the likelier cause is that NS is not set,
so Ingo checks the Rakefile, finds it fine, and is stuck. It also claims
a title containing a comma is cut short. In fact the command stops with a
clear error about the part after the comma, and the real advice is simply
to quote the title.

**Expected:**
Each troubleshooting entry names the actual cause and the actual fix.

**STEPS TO REPRODUCE:**
1. In a dashboard setup, run rake "story:lint" without NS - the task is
   unknown, though the Rakefile is correct
2. Run NS=APP rake "story:chore[Fix login, then logout]" - it stops with a
   field error rather than cutting the title short

**REFERENCE:**
- docs/troubleshooting.md
- BT-127
- BT-ADR-0009

- [x] The missing task entry leads with setting NS
- [x] The comma entry describes the error that actually appears
- [x] The remaining troubleshooting entries are checked against real behavior
