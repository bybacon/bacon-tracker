---
status: accepted
date: 2026-09-13
deciders: [alex]
stories: [BT-129, BT-134, BT-136]
tags: [docs, layout, registry]
---

# `/tracker` and `/docs` are sibling roots, registered independently and both optional

- Date: 2026-09-13
- Related chores: BT-129 (rename), BT-134 (move + registry keys), BT-136 (reveal scope)
- Relates to: BT-ADR-0015 (docs is a surface), BT-ADR-0014 (ADRs are tracked
  records), BT-ADR-0012 (dashboard registry), BT-ADR-0010 (state is the filesystem), BT-041
  (where the gem's own tracker should live)

## Status

Accepted

## Context

BT-ADR-0015 puts docs and stories in one product reading one registry. That
forces a layout question the registered projects have already answered three
incompatible ways: stories live under `docs/tracker/`, in `tracker/` at the
repository root, or in a **different repository entirely** - this project's own
stories are in the parent repo while its decisions are not.

The majority layout is the confusing one. `docs/tracker/` puts work state inside
the documentation folder, and a story is not documentation - it is work in
flight, and it is in nobody's mental model of "the docs". Some projects
independently moved it out to the root, which is a signal. A decision, by
contrast, *is* documentation: people link to `docs/decisions/…` from READMEs,
and every project with a docs tree keeps them there.

The naming has already collided. `Configuration#docs_root` today means **the
tracker's story directory** - both Rakefiles read
`c.docs_root = File.expand_path("docs/tracker", __dir__)`. The moment a real
docs root exists, that attribute name is actively wrong. The gem is not
published outside a private registry, so renaming it costs a handful
of Rakefile lines now and a deprecation cycle later.

BT-ADR-0014 also changed what `docs/` contains. `docs/decisions/` now carries
`.next-id`, `proposed.md` and one subdirectory per status - it is a *tracked*
subtree with a board, a lint and id allocation - while `guides/`, `personas/`,
`runbooks/`, `overviews/` and `handovers/` stay free prose. So the docs tree is
no longer uniform, and a layout that assumes it is will not survive the next
tracked record type.

## Decision

### One rule

**`/tracker` is what you're doing. `/docs` is what you know.**

Both are siblings at the repo root. Stories move out of the documentation
folder; decisions stay in it.

```
README.md   CHANGELOG.md   VERSION        project identity

tracker/                                  what you're doing
  .next-id   backlog.md
  features/  bugs/  chores/   → 1_icebox 2_backlog 3_started 4_done

docs/                                     what you know
  decisions/                              tracked subtree
    .next-id   proposed.md   _template.md
    proposed/  accepted/  rejected/  deprecated/  superseded/
  guides/  personas/  runbooks/  overviews/  handovers/
  anything.md                             loose files are pages too
```

Depth and naming inside `docs/` are free. Loose files at its top level are
already real across registered projects - a stray handover note, a `TODO.md`, a
`Home.md` - and render as pages without a folder.

### A tracked subtree is self-describing

A folder is **tracked** if it contains `.next-id`. It then carries its own id
counter, its own list file and its own board; nothing above it needs to know it
exists. `tracker/` has `backlog.md`; `docs/decisions/` has `proposed.md`.

This is detection, not configuration - the rule the idea capture set for special
views, applied to the layout. Three things follow:

- **A third record type is a placement question, not an architecture question.**
  Work-shaped goes under `/tracker`, knowledge-shaped under `/docs`; the only
  new code is its status vocabulary and its view. A future `docs/reviews/` grows
  a `.next-id` the day reviews are worth tracking, and no registry entry or
  folder-name special case is involved.
- **A tracked subtree is relocatable.** Being self-contained means moving one is
  a `git mv`, not a schema change.
- **`.next-id` must be written at init**, not lazily on first use as today, or
  the marker is unreliable. This changes `tracker-init`, not `Core`'s
  missing-file tolerance: a `.next-id` that has gone missing still reads as 1.

### Both roots register independently, and both are optional

`dashboard.md` entries gain two optional keys:

```markdown
## A Conventional Project
path: ../someproject
namespace: SOME

## A Project Keeping Stories At The Root
path: ../someproject
namespace: SOME
tracker: tracker            # non-default location

## Bacon Tracker
path: ../tracker/bacon-tracker
namespace: BT
tracker: ../docs/tracker    # stories in the parent repo (BT-041)
```

- **`path:` stays mandatory**; it is the project root, and both other keys
  resolve against it. `../` is permitted - this gem's stories genuinely live in
  another repository.
- **`tracker:` defaults to `tracker/`, `docs:` defaults to `docs/`.** A project
  following the convention needs neither key. This is the point of choosing a
  convention at all.
- **Either surface may be absent.** A project with only a tracker shows a board;
  one with only docs shows docs; one with both shows both. Neither is required,
  and a project with neither does not belong in the registry.
- **An absent default and a broken override are different.** No `docs/` at the
  default path means "this project has no docs" - silent, no surface. An
  explicit `docs:` pointing somewhere that does not exist is a typo and warns,
  the way `Dashboard#build_project` already warns for a missing `path:`.
- **Overlap is tolerated, not forbidden.** A repo that keeps `docs: docs` with
  `tracker: docs/tracker` still works: where the tracker tree falls inside the
  docs tree, the docs surface skips it. Derived from the two paths, never
  configured separately.

That last rule is what makes the convention a convention rather than a
requirement. **Every repo can move on its own schedule**, or not at all, and the
registry says which layout it is using.

### Rename

`Configuration#docs_root` becomes `tracker_root`, freeing `docs_root` for its
literal meaning. Done now, while the gem has no consumers outside this ecosystem.

## Consequences

- The layout states the distinction it encodes. "Work is not documentation" is
  visible in the directory listing rather than explained in a vocabulary file.
- **A conventional project needs no configuration at all** - `path:` and
  `namespace:` and nothing else. The exclusion rule, the two path keys and the
  registry's growth all disappear for the common case.
- Adding a tracked record type later touches no layout code, no registry schema
  and no folder-name list.
- Migration is per-repo and unforced: a project moves `docs/tracker/` →
  `tracker/` when convenient (a `git mv`, one Rakefile line, CI paths and any
  inbound links), and until then carries one `tracker:` key. Projects already
  keeping stories at the root need nothing.
- **Cost: inbound links break on each move.** Prose, CI configs and skills that
  name `docs/tracker/...` must be swept with the `git mv`, the same obligation
  BT-ADR-0014's rename sweep carries.
- **Cost: the rename touches every consumer's Rakefile.** Small, internal,
  and strictly cheaper than the deprecation cycle it would need after the gem is
  published.
- **Cost: `.next-id` at init is a behaviour change** for anyone who hand-creates
  a tracker directory and expects the Rake tasks to fill it in.
- This gem remains the exception - its stories in the parent repo, its decisions in
  its own repo - until BT-041 is unparked. The registry expresses it; it is not
  resolved here.

## Amendment - 2026-09-14 (BT-155)

Three corrections found by review. The decision stands; these are claims about
it that do not hold.

**1. `.next-id` marks a tracked subtree; it does not select a vocabulary.** The
Decision says a third record type is "a placement question, not an architecture
question… no registry entry or folder-name special case is involved." `.next-id`
can only answer *whether* a folder is tracked. Something must still map a
tracked folder to its status set and its view, and today that is the folder
name: **`decisions` selects the five-status vocabulary.** A future record type
adds its own mapping. The "no folder-name special case" claim is withdrawn.

**2. The registry example in the Decision is pre-BT-134.** It shows
`tracker: ../docs/tracker` for this gem. BT-134 moves that tree to `tracker/`,
after which the key reads `tracker: ../tracker`. The example illustrates the
cross-repository case, not a current path.

**3. BT-041 is decided, not parked.** Two passages say this gem "remains the
exception… until BT-041 is unparked". BT-041 was resolved 2026-08-08 and
**rejected** moving `docs/tracker` into the gem repo, because the tracker is
product-wide. The exception is therefore permanent by decision, not pending one.

## Amendment - 2026-09-14 (BT-134)

**`path:` in an existing registry is the tracker root, and that is detected
rather than broken.** The Decision defines `path:` as the project root with
`tracker:` defaulting to `path/tracker`. Every `dashboard.md` written before
this decision points `path:` straight at the directory holding `backlog.md`, so
taking the Decision literally would have re-rooted every registered project at
once - and the failure mode is silent, since a tracker root that does not exist
renders an empty board rather than an error. A past review already
named that as this codebase's worst class of bug.

So: **a `path:` whose directory contains `backlog.md` or `.next-id` is treated
as the tracker root**, and the project root is taken to be its parent. An
explicit `tracker:` always wins over the detection. Nothing in an existing
registry changes, and a project moving to the sibling-roots layout simply stops
matching the legacy shape.

This is the same rule the Decision already applies to layout - detection, not
configuration - extended to the registry that describes it.

## Amendment - 2026-09-25 (BT-179)

**One configuration, two callers.** The Rake tasks installed by
`Tasks.install_for_dashboard` built their own configuration from a registry
entry and took `path:` - the project directory under this record - for the
tracker root. Stories created with `NS=... rake` landed beside `tracker/`
instead of in it, and the decision tasks had no decisions root at all.
`Dashboard#config_for` is now the single place a registry entry becomes a
configuration; the server and the Rake tasks both use it.

**`tracker-init` writes the current form.** It registers `path:` as the project
directory. The older form, `path:` pointing at a tracker directory, is still
detected as the BT-134 amendment describes.

**The gem is public.** "Not published outside a private registry" no longer
holds; future registry changes are versioned changes.
