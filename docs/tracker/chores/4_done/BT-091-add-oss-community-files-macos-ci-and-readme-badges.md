---
id: BT-091
type: chore
status: done
---

Title: Add community files, macOS CI and README badges

**Description:**
The repository lacked what outside contributors expect from an open-source
project: contributing and conduct guides, a way to report vulnerabilities,
and a pull request template they can actually fill in. CI ran only on
Linux, although the product is built around macOS. The README had no badges
and no picture of the board. Filling these gaps makes the project ready for
a public release.

**Resources:**
- CONTRIBUTING.md
- CODE_OF_CONDUCT.md
- SECURITY.md
- .github/PULL_REQUEST_TEMPLATE.md
- .github/workflows/specs.yml
- README.md
- BT-013

- [x] Contributing, code of conduct and security policy files exist
- [x] The pull request template works for outside contributors
- [x] The test suite also runs on macOS in CI
- [x] The README shows build and version badges and a board screenshot
