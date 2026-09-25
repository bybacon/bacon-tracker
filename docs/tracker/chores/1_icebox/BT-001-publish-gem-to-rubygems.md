---
id: BT-001
type: chore
status: icebox
---

Title: Publish the gem to RubyGems

**Description:**
The gem is feature-complete but not yet on RubyGems. Publishing it lets anyone install it with `gem install bacon-tracker` and set up a project in minutes, and lets the menu bar app depend on a released version. The release is cut from a version tag, and the publish workflow builds and pushes the gem from there.

**Resources:**
- docs/releasing.md
- .github/workflows/publish.yml
- CHANGELOG.md
- BT-040

**Pre-release checklist:**
- [x] The full test suite passes
- [x] The version is set to 1.0.0
- [x] The gem packages the library, executables, README, CHANGELOG and LICENSE, without the docs folder
- [x] The publish workflow runs the tests, checks the tag matches the version, then pushes the gem
- [ ] RubyGems trusted publishing is set up for this repository and its publish workflow
- [ ] The CHANGELOG entry for 1.0.0 carries the release date instead of "Unreleased"
- [ ] The release is tagged with `bundle exec rake version:release`, which starts the publish workflow
