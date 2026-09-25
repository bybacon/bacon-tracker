# Demo tracker

A small, pre-populated tracker so you can see the board immediately - no setup.
It holds 11 example stories (features, bugs, and chores) spread across **icebox → backlog → started → done**, with T-shirt sizes, a couple of assignees, a blocked-by link (`DEMO-004` is blocked by `DEMO-003` - so `DEMO-003` shows the derived amber "blocks" badge in return), a symmetric `linked_to` (`DEMO-003` ↔ `DEMO-006`, rendered as a 🔗 on both), and a started story with subtasks.

## Run it

From this directory:

```bash
rake story:server                          # single-project board → http://localhost:4567
```

or the multi-project dashboard:

```bash
tracker-dashboard --dashboard dashboard.md  # → http://localhost:4567
```

From a checkout of this repo (rather than the installed gem), prefix with `bundle exec`, e.g. `bundle exec rake story:server`.

## Poke at it

It's just files - everything the board does is a file move under `tracker/`. The demo's `Rakefile` is a standalone one, so no `NS=` is needed:

```bash
rake "story:feature[Try adding a story]"   # from this directory
rake story:lint                            # check backlog ↔ files agree
```

The quotes matter in zsh (the macOS default), which otherwise reads `[ ]` as a glob.

> This tracker is a fixture for demos and screenshots; feel free to edit it and
> `git checkout` to reset.
