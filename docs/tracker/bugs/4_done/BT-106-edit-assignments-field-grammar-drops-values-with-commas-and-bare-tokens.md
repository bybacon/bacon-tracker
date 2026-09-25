---
id: BT-106
type: bug
status: done
---

Title: Rake field values with commas or a missing field name go wrong

**Currently:**
When Jean sets a title that contains a comma followed by an `=` sign, such
as "Compare a=1, b=2", the command stops with "Unknown field(s): b"
instead of setting the title. When Jean forgets a field name, as in a size
given as a bare `M`, the value is silently dropped: the story is created
without a size and the command reports success.

**Expected:**
Values may contain commas and `=` signs without being read as new fields.
A value with no field name is an error, not a silent drop.

**STEPS TO REPRODUCE:**
1. Run rake "story:feature[Some title,M]" - the story is created with no
   size
2. Run rake "story:edit[APP-001,title=Compare a=1, b=2]" - the command
   stops with an unknown field error

**REFERENCE:**
- BT-ADR-0009
