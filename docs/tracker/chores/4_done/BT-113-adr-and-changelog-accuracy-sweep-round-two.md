---
id: BT-113
type: chore
status: done
---

Title: Correct the decision records and changelog that contradict the code

**Description:**
Several decision records and a changelog entry no longer matched how the
tracker behaves. Contributors use these records to decide how new code
should work, so a wrong record invites a wrong change. One could even lead
to code that stops the server. Correcting them keeps the decision log
something Ingo can trust months later.

**Resources:**
- CHANGELOG.md
- BT-ADR-0003, BT-ADR-0005, BT-ADR-0006, BT-ADR-0011
- BT-102

- [x] The error-handling record lists every action the board can trigger
- [x] The records and changelog say lint reports status drift rather than fixing it
- [x] The command-install record is marked as amended by the opt-in install
- [x] The id record describes how ids are really locked
