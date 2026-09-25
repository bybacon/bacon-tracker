---
id: BT-018
type: chore
status: done
---

Title: Set the id prefix explicitly in the id format test

**Description:**
The test for formatting story ids expected a particular prefix without setting it, relying on the default configuration. A reader could not tell whether it was testing the default on purpose or had simply skipped the setup. Setting the prefix explicitly, as neighbouring tests already do, makes the test's intent clear.

**Resources:**
- spec/bacon_tracker/core_spec.rb
