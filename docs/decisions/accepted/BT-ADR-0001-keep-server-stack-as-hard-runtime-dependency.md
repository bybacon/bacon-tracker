---
status: accepted
date: 2026-07-11
stories: [BT-033]
---

# Keep the server stack (sinatra/puma/rackup) as hard runtime dependencies

- Date: 2026-07-11
- Related chore: BT-033

## Status

Accepted

## Context

CVE-2026-47737 required bumping puma past the `~> 6.0` pin in the gemspec. While fixing the pin, an inconsistency surfaced: puma and sinatra are declared as hard runtime dependencies, yet `tasks.rb` guarded the `story:server` and `story:dashboard_server` tasks with a `rescue LoadError` that told users to add sinatra to their Gemfile - implying the server stack is optional. Both postures existed at once.

Options considered:
1. Keep sinatra/puma/rackup as runtime dependencies and delete the LoadError guards.
2. Make the server stack optional: remove the runtime dependencies, keep the LoadError guards, document that the dashboard requires a separate install.

## Decision

Keep the server stack as hard runtime dependencies (option 1). The kanban web UI is a core feature of the gem, not an add-on; the LoadError guards in `tasks.rb` are deleted because the dependencies are guaranteed present. The puma constraint is `>= 7.2.1, < 9` (floor = first patched release for CVE-2026-47737, ceiling = one major of headroom).

## Consequences

- Easier: `rake story:server` always works after `gem install bacon-tracker`; no divergent install paths to document or test.
- Easier: security posture is auditable from the gemspec alone.
- Harder: Rake-only consumers install sinatra/puma/rackup they may never load (install-size cost only; the tasks never `require` them unless the server tasks run).
- If a dependency-light install ever becomes a real user need, supersede this ADR with a split-gem approach rather than reintroducing optional-dependency guards.

## Amendment - 2026-09-25 (BT-179)

The sinatra constraint is `~> 4.1`, not `~> 4.0`. `set :host_authorization`,
which pins the Host header to localhost and is the server's DNS-rebinding
guard, first exists in 4.1; under 4.0 the setting is silently ignored. The
floor is the version where the guard is real. `bin/tracker-dashboard`'s
leftover sinatra `LoadError` rescue is deleted for the reason this record
already gives.
