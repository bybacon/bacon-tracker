---
id: BT-040
type: chore
status: done
---

Title: Harden CI before the first public release

**Description:**
The gem claimed to support Ruby versions that CI never ran, the workflows ran with broader repository access than they needed, and publishing relied on a long-lived RubyGems API key stored as a secret. Before the first public release, the supported Ruby versions should be the ones CI actually tests, each workflow should ask only for the access it uses, and publishing should use RubyGems trusted publishing so no key needs to be stored.

**Resources:**
- .github/workflows/specs.yml
- .github/workflows/publish.yml
- bacon-tracker.gemspec
- BT-001
