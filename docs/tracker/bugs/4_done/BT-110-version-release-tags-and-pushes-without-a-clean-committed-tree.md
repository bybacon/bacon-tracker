---
id: BT-110
type: bug
status: done
---

Title: A release can be tagged and pushed before the version bump is committed

**Currently:**
When Ingo bumps the version and releases straight away, the release is
tagged and pushed even though the bump is still an uncommitted change. The
tag points at a commit that still carries the old version number. It is
pushed for good, and the publish step then fails or ships the wrong
version.

**Expected:**
Releasing stops with a clear message when there are uncommitted changes or
when the committed version doesn't match the one being tagged. The docs
describe bump, commit, release as the order.

**STEPS TO REPRODUCE:**
1. Run rake "version:patch"
2. Without committing, run rake "version:release"
3. The pushed tag points at a commit with the previous version

**REFERENCE:**
- BT-062
