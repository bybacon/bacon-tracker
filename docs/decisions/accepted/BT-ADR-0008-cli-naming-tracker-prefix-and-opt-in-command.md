---
status: accepted
date: 2026-08-16
stories: [BT-072]
---

# CLI naming: `tracker-` executables, `bacon-tracker` gem, opt-in /tracker command

- Date: 2026-08-16
- Related story: BT-072

## Status

Accepted

## Context

Two identities are in play. The gem's publishing identity on RubyGems belongs to
the lab (`bacon-`). The commands a user types belong to the tool they are running
- "the tracker." Conflating them makes the run-commands advertise the lab rather
than the tool. Separately, the `/tracker` Claude Code command is useful only to
Claude Code users, so writing it into every project is files others never asked
for.

## Decision

- Executables are `tracker-init` and `tracker-dashboard` - the run identity names
  the tool.
- The gem stays `bacon-tracker` - the publish identity names the lab.
- `tracker-init` installs the `/tracker` command only with `--command`; by
  default it writes no `.claude` files, and the setup summary states the choice.

## Consequences

- The commands you type say "tracker"; the package you install says
  "bacon-tracker". The split is deliberate - publish identity and run identity
  serve different audiences.
- Non-Claude users get a clean setup with nothing they did not request.
- Executable names are an interface: anything that launches them by name (e.g.
  the BaconTrackerMenu app, which stores a path to `tracker-dashboard` and matches
  the process command line to reclaim its port) couples to them, so a rename is a
  breaking change for those consumers - see BT-073.
