---
id: BT-010
type: chore
status: done
---

Title: Pin the web server dependencies to known major versions

**Description:**
The gem required its web server libraries with no version limit, while the web framework was already pinned to a major version. A fresh install could pull in a new major release the tracker was never tested with and break without warning. Pinning each dependency to the major version it was built against keeps installs predictable for anyone setting up the tracker.

**Resources:**
- bacon-tracker.gemspec
