---
id: BT-159
type: chore
status: done
---

Title: Add the missing security and failure scenarios to the docs features

**Description:**
The docs features left gaps, two of them security-relevant. The page that
returns file contents had no scenario refusing paths outside the docs tree,
and following relative links from a page had no traversal refusal either.
Creating a decision from the template could produce a record that fails the
lint, and superseding a record with a target that cannot be found had no
scenario requiring a clean refusal. Adding these scenarios, and marking the
two reading stories as security-relevant, makes sure the builds cover them.

**Resources:**
- BT-139, BT-140, BT-145, BT-146
- BT-136
- BT-ADR-0017
