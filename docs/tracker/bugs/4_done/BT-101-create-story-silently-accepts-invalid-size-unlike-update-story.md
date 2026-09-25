---
id: BT-101
type: bug
status: done
---

Title: Creating a story with an invalid size silently drops it

**Currently:**
When a story is created with a size other than S, M or L, such as XL, it
is created without any size and without a word of warning. Editing an
existing story with the same value is refused with "size must be S, M, or
L", and so is the rake command. Ingo believes a size was set when it
wasn't.

**Expected:**
Every way of creating or editing a story follows the same rule: an invalid
size is refused with the same message, and nothing is created.

**STEPS TO REPRODUCE:**
1. Create a bug with size XL through the board's API
2. The story is created with no size and no error
3. Edit the story with size XL - it is refused with "size must be S, M, or L"

**REFERENCE:**
-
