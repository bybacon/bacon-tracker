---
status: accepted
date: 2026-07-11
---

# Keep local version tasks instead of depending on an internal version-task gem

- Date: 2026-07-11

## Status

Accepted

## Context

`Tasks.install_version_tasks` hand-rolls `version:current|patch|minor|major|release`, duplicating functionality an internal, unpublished version-task gem already provides as the shared source for these Rake tasks in other projects. Two semver-bump implementations now exist.

Options considered:
1. Depend on the internal gem (dev dependency) and adapt bacon-tracker to its `VERSION`-file convention
2. Extend the internal gem to support a configurable version-file target, then delete `install_version_tasks`
3. Keep the local copy and document why

## Decision

Keep the local version tasks (option 3). bacon-tracker is headed for public RubyGems publication (BT-001); the version-task gem is internal and unpublished, so a dependency - even dev-only via a git/path source - would break `bundle install` for external contributors and complicate the gemspec. The local implementation is ~35 lines and changes rarely.

The one real defect in the local copy - `content.sub(current, new_version)` replacing the first occurrence of the version string anywhere in `version.rb` - was fixed alongside this decision by anchoring the sub to the `VERSION = "…"` assignment.

## Consequences

- Easier: the gem stays dependency-light and installable by the public; no coupling to internal infrastructure.
- Harder: version-task fixes must be applied in two places (the internal gem and here) - accepted because the surface is tiny and now deliberate rather than accidental.
- Reconsider if the internal gem is ever published publicly or if the local tasks grow beyond trivial.
