---
status: accepted
date: 2026-09-13
deciders: [alex]
stories: [BT-137]
tags: [docs, packaging, product]
---

# Docs is a surface of bacon-tracker, not a second product

- Date: 2026-09-13
- Related chores: BT-137 (split server.rb before the surfaces land)
- Relates to: BT-ADR-0014 (decisions are tracked records), BT-ADR-0012 (dashboard
  modes), BT-ADR-0003 (parent repo as its own repo)

## Status

Accepted

## Context

Every project this tracker is registered against keeps prose beside its stories
- decisions, guides, personas, runbooks, overviews, handovers - in a `docs/`
tree, rendered today by nothing but `ls`, `grep` and GitHub. The proposal was a
sibling gem, "Confluence to the tracker's Jira", reading those same trees. The
first packaging sketch had three pieces: a shared gem holding the project
registry, the theme tokens, `slugify`, the frontmatter grammar and the Sinatra
boot, with tracker and docs as independent consumers.

Two things undercut that, one of them a decision made since.

**BT-ADR-0014 made decisions tracker-shaped.** A decision now has a namespaced
id issued from a locked `.next-id`, a status directory, frontmatter mirroring
it, a derived-and-ordered `proposed.md`, and a lint with BT-ADR-0013's severity split.
That is not a docs feature resembling the tracker; it is this project's data
model applied to a record whose stages happen to be statuses. A second gem would
either duplicate those primitives or reach for them through a third gem -
ceremony in both directions.

**And the user-facing case for a split does not exist.** Across the projects
registered today, **every one with a docs tree also has a tracker**; there is no
instance of one without the other. For several of them `docs/` contains nothing
but `decisions/`, so a separate docs product would render exactly one folder -
the folder that is really tracker mechanics.

The costs of splitting are structural rather than speculative. This product is
already three repositories (the parent repo, the gem, the menu bar app); a shared
gem plus a docs gem makes five, each carrying its own CI workflows, gemspec,
lockfile, version tasks, CHANGELOG and private-registry release. Every change to
a shared gem becomes a release plus two version bumps in lockstep, and every
consumer inherits the registry's authentication as a build-time dependency -
a chain this ecosystem has already been bitten by once.

Two servers is the smaller cost and points the same way. `tracker-dashboard`
runs **one process on one port for every registered project**; a second server
does not scale per project, it is simply one more thing to start, bookmark and
teach the menu bar app.

There are no external users yet - the gem is published only to a private
registry - so no published promise constrains the shape.

An earlier draft split the work by internal coupling: decision tracking into the
tracker, the generic docs reader as its own project. That was the same technical
cut wearing a product costume. It separates a project's decisions from the
guides and runbooks sitting beside them, which nobody experiences as two things,
and it was rejected for that reason.

## Decision

**Docs is a surface of bacon-tracker.** One gem, one binary, one port, one
registry, one menu bar app. No second gem and no shared-gem extraction.

- The dashboard gains a docs surface alongside the board, served by the same
  process from the same registry.
- **It is optional by detection, not configuration.** A project with a docs tree
  gets a docs surface; one without gets nothing, and nothing changes for it.
  This is the existing missing-file posture - `story_dirs` skips absent subdirs,
  an empty directory reports all-zeros stats - extended.
- **Cross-links between decisions and stories are direct.** In one process,
  resolving a record's `stories:` key against the board is a method call. Across
  two gems it would have been a URL guessed against a server that may not be
  running, which is the single capability the split would have cost.
- The shared-gem questions - its name, its home, release mechanics for a
  three-consumer private gem - are **closed, not deferred.** There is no shared
  gem.

**Revisit when, and only when, someone wants docs without a tracker.** That is
the one fact this decision rests on, and it is measurable: an external user
asking for the reader alone, or a registered project growing a docs tree with no
work to track. Until then a split would pay five repositories' overhead for a
separation no user perceives.

## Consequences

- One install, one port, one tray icon, one thing to update. A project appears
  once in one registry and shows whichever surfaces it has.
- The decision-to-story cross-link is available directly rather than degraded to
  a soft link.
- BT-ADR-0014's primitives - `consume_id`, list healing, frontmatter, lint,
  namespace - gain a second consumer rather than a second implementation.
- Two repositories that would have existed do not, and with them two release
  pipelines and an added private-registry dependency.
- **Cost: the product's one-line description grows.** "Manages stories, bugs and
  chores, plus a local board" is cleaner than one that also renders docs. The
  gem is not public yet, so this is a description to write rather than change.
- **Cost: `server.rb` is already 1380 lines with inline templates**, and the docs
  surface will not be small. Splitting it, or moving templates out of `__END__`,
  is now load-bearing rather than cosmetic - but that is an internal structure
  problem, not a packaging one.
- **Cost: a tracker-only user carries code they never run.** Detection keeps it
  invisible and inert; it is still shipped weight, and it is the price of not
  maintaining five repositories.
- This decision settles packaging only. The folder layout and how the two trees
  are registered are decided in BT-ADR-0016.

## Amendment - 2026-09-25 (BT-179)

The gem is released publicly on rubygems.org as 1.0.0. The passages that say
it has no external users and is published only to a private registry describe
the state when this record was accepted; the decision itself does not depend
on them. From 1.0.0 on, a rename or removal on this surface follows semantic
versioning like any other public interface.
