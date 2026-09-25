---
status: accepted
date: 2026-09-13
deciders: [alex]
stories: [BT-130, BT-131, BT-132]
tags: [adr, docs]
---

# ADRs are tracked like stories: namespaced ids from `.next-id`, a status directory, YAML frontmatter, and an ordered `proposed.md`

- Date: 2026-09-13
- Related chores: BT-130 (lint), BT-131 (this project), BT-132 (skill + command)

## Status

Accepted

## Context

This project keeps its architecture decisions in `docs/decisions/`, and until
now they were plain prose with no contract at all. Thirteen records named
`0001-…` through `0013-…`, each opening with a `# heading` and a `## Status`
line written by hand.

Nothing about that is machine-readable, and three specific gaps follow.

**Status is a sentence, so nothing can be asked of it.** `## Status` is
free-form: a word, sometimes a date, sometimes a clause explaining who decided
and when. A question as basic as *"which decisions are still proposed?"* cannot
be answered without opening every file and reading English. The format also
invites drift - capitalisation, date style and wording vary the moment more than
one person or more than one project writes records this way - and a checker that
never opens the file cannot notice.

**Ids are not citable.** A bare `BT-ADR-0007` means nothing outside the directory it
lives in. This tracker is explicitly multi-project (BT-ADR-0012): one dashboard, one
registry, many projects, each with its own namespace. Decisions referencing each
other across projects - one project adopting a convention another one settled -
have no way to say so, and slug-only names collide constantly (`testing.md` and
`database.md` are the decisions every project eventually writes).

**There is no frontmatter**, so any consumer wanting structure has to parse
prose, and the prose is not parseable. That is what blocks the decisions board:
a view grouped by status cannot be built over a corpus where status is a
paragraph.

Two conventions were already emerging on their own and are worth keeping rather
than replacing. Records append `## Amendment - DATE (STORY)` sections instead of
rewriting history, which is the right instinct for an immutable record. And the
narrative under `## Status` frequently carries real information - who decided,
under what circumstances, what it complements - that a single enum value cannot.

The mechanism to adopt is not novel, because this project already has it. BT-ADR-0006
settled that **the stage directory is the source of truth** and a story's
`status:` frontmatter mirrors it, with the lint asserting they agree; BT-ADR-0011
issues story ids from `.next-id` under a file lock; `backlog.md` is an ordered
list whose membership is derived and self-healing. A decision is a record in the
filesystem, exactly as a story is. It needs the same machinery, not a parallel
one.

This is recorded as one decision rather than four because the parts are not
independently adoptable: a status set is unenforceable without somewhere to put
it, frontmatter needs a stable id to reference other records by, numbering
without a lint just adds a rename, and a list of proposed records needs a
definition of "proposed". Adopting any one alone leaves the corpus as unreadable
as it was.

## Decision

### The directory is the status

`docs/decisions/` holds one subdirectory per status, and **a record's directory
is the source of truth for its status** - BT-ADR-0006, applied unchanged:

```
docs/decisions/
  _template.md
  .next-id
  proposed.md
  proposed/    accepted/    rejected/    deprecated/    superseded/
```

The status set is closed and lowercase: **`proposed` · `accepted` · `rejected` ·
`deprecated` · `superseded`**. Lowercase is canonical so comparison needs no
normalisation, and the directory names are the status names - there is nothing
to map.

### The filename is the id, and the id is namespaced

A record is a file matching **`<NS>-ADR-NNNN-slug.md`** inside a status
directory. Nothing else is a record: `_template.md`, `proposed.md` and any stray
file are not, and no tool needs a heuristic to decide.

- **`<NS>` is the project's tracker namespace**, read from the same registry
  entry the board uses. One namespace per project, shared by its stories and its
  decisions. A project with no tracker declares a namespace anyway; it costs one
  line and buys a citable id.
- **`ADR` is the record-type token and is required.** Story ids carry no type
  (`BT-129` may be a feature, bug or chore - the directory says which), but
  decisions are a separate sequence in the same namespace, so without the token
  `BT-0014` and story `BT-14` would be two records with one id.
- **Four digits, zero-padded.** The slug stays: grep and tab-completion need it.
- **Ids are issued from `docs/decisions/.next-id` under a file lock**, exactly as
  BT-ADR-0011 issues story ids - a separate counter in the same namespace, floored above
  the highest id on disk on every read so a merge conflict or a hand edit can
  never reissue a live id, and starting at 1 when absent.
- **Immutable once assigned, never reused, gaps allowed** - as a deleted story
  keeps its id. A record keeps its id and its slug when its status changes; only
  its directory moves.

**There is one reference grammar.** `BT-ADR-0014` means the same thing written
in any project, in a commit message, or pasted into a chat. No same-repo short
form and no separate cross-project syntax - the namespace is what lets the id
travel.

### Frontmatter carries only what the file cannot say itself

```yaml
---
status: accepted
date: 2026-07-12
deciders: [alex]
supersedes: [BT-ADR-0009]
superseded_by: []
stories: [BT-249, BT-016]
canonical: <NS>-ADR-NNNN
tags: [offline, bundle]
---
```

**`status` and `date` are the only required keys.** Everything else is optional
and omitted when empty.

There is deliberately **no `id` and no `title` key.** The filename states the id
and the `#` heading states the title; a key that can only ever drift from
something the file already says earns nothing and costs a lint rule.

| key | type | meaning |
|---|---|---|
| `status` | one of the five | **mirrors the directory**, which is authoritative. The lint asserts they agree - BT-ADR-0006's rule for stories, unchanged. |
| `date` | `YYYY-MM-DD` | the day the decision **took effect**. While `proposed`, the day the record was written; it moves once, to the day it is accepted or rejected, and never again. |
| `deciders` | list | who made the call. |
| `supersedes` | list of ADR ids | decisions this one replaces. |
| `superseded_by` | list of ADR ids | decisions that replace this one. |
| `stories` | list of story ids | the work that produced or applied the decision. |
| `canonical` | one ADR id | **adoptions only** - this project's local record of a decision another project owns. |
| `tags` | list | free. No controlled vocabulary; add one later if it earns it. |

Both id kinds are namespaced and self-describing: `BT-ADR-0004` is a decision,
`BT-258` is a story, and either can be read without knowing which file it came
from.

**An adoption is a real record.** It has its own id, its own directory and its
own local consequences; `canonical:` records that it defers to another project
on the decision itself, rather than demoting the local record to a pointer.

### `## Status` is narrative, and `## Amendment` is how a record changes

With the directory authoritative and `status:` mirroring it, the prose
`## Status` section is no longer the machine's source - it is the slot for *why*
this status, decided when and by whom, which an enum cannot hold. It stays, and
the lint only **warns** if its first word contradicts the directory; a third
hard mirror would be one too many.

`## Amendment - YYYY-MM-DD (STORY)` is how an accepted record changes,
consistent with records being immutable. A status change moves the file, updates
`status:` and appends an amendment saying why; `date` never moves, so "decided
2026-07-03, superseded 2026-08-02" is recoverable without a second date key.

### `proposed.md` orders the decisions still to be made

`docs/decisions/proposed.md` is the decision todo list, in the tracker's own
format:

```markdown
# Decisions to make, in order

- BT-ADR-0018 - whether the menu bar app serves both surfaces
```

**It is deliberately not called `backlog.md`.** `vocabulary.md` is explicit that
*"icebox and backlog are stages, not moods"* - the backlog is one of four story
directories holding the 3–7 stack-ranked items you will do next. This list is
neither bounded to 3–7 nor backed by an icebox, and borrowing the word would
make it a near-homonym of a term this project keeps precise. `proposed.md` names
its own membership rule, and a second list would name itself the same way.

- **Membership is derived, never authored** - a record is listed if and only if
  it sits in `proposed/`.
- **Ordering is the one thing a human supplies**, and the only reason the file
  exists. `vocabulary.md` already states the principle for stories - *"there is
  no priority field… position in `backlog.md` is the priority"* - and it carries
  unchanged.
- **It self-heals under the lock.** `heal_backlog!` is the same routine over a
  configured path: entries whose record is gone or has moved out of `proposed/`
  are dropped, new ones are appended at the bottom, and non-entry lines are
  preserved.
- **`proposed` is the only non-terminal status.** The other four are outcomes, so
  one list is enough.

**There is no icebox and no started stage.** A decision that could wait should
not be a record yet, and the work of deciding happens in a conversation, not in
a file.

### The lint, with BT-ADR-0013's severity split

BT-ADR-0013 settled the reference rule for stories and it transfers unchanged: **only
ids in this project's own namespace are resolvable references.** An id in
another namespace is external and passes unchecked - this checkout cannot
resolve it either way, and the other project may not be present.

**Failures** - a record with no frontmatter block; missing or unparseable
`status`/`date`; a `status` outside the five; a `status` disagreeing with its
directory; a `date` that is not ISO-8601; a filename whose `<NS>` is not this
project's namespace; a duplicate number; an own-namespace `supersedes` /
`superseded_by` id that does not resolve; an own-namespace supersession that is
asymmetric; a `proposed.md` entry naming a record that does not exist; a record
in `proposed/` missing from `proposed.md`, or a listed record that has moved out
of it; a `.next-id` at or below the highest id on disk.

The `proposed.md` findings are the ones `heal_backlog!` repairs during any
mutation, so the lint sees them only after a hand edit. They fail rather than
warn for BT-ADR-0013's reason: they are integrity, not flow.

**Warnings** - a `.md` file in a status directory that is not a valid record
filename (the forgotten-id case); `status: superseded` with an empty
`superseded_by`; a `## Status` first word contradicting the directory; a
`canonical:` id in this project's own namespace.

**Unchecked** - any id outside this project's namespace, in any key.

**No index file is required.** `proposed.md` is not one: it lists only the
records in `proposed/` and exists for their *order*, which nothing else can
express. An index of every decision would be duplication - the directory is the
index (BT-ADR-0010), and the docs surface renders it.

### Adoption

This project's thirteen existing records are migrated with this decision:
renamed to `BT-ADR-NNNN-…` with `git mv`, moved into `accepted/`, and given
frontmatter additively so every body stays byte-identical. `.next-id` and
`proposed.md` are seeded, and `_template.md` is added.

A project adopting the contract later follows the same order, and the order
matters:

1. **Lint first, red.** It must report the pre-migration tree and exit 1 before
   any file is touched. A lint written after the backfill proves nothing.
2. **Assign ids in date order** - from the `## Status` date, falling back to the
   file's first commit - so the sequence is chronologically meaningful rather
   than alphabetical by accident. `git mv` to keep history.
3. **Backfill frontmatter only**, then verify every body is byte-identical.
4. **Batch the judgement calls for a human**: any status that is not one of the
   five, and which records are adoptions of another project's decision. These
   are not automatable and must not be guessed.
5. **Seed `.next-id` and `proposed.md`**, the counter above the highest assigned
   id and the list derived from `proposed/`, then ordered by hand.
6. **Fix inbound references** - prose citing a record by its old path or number.
   A rename sweep that leaves dangling links trades one drift for another.
7. **Wire the lint into CI** so the next drift fails a pull request.

## Consequences

- "Which decisions are still proposed?" is answered by listing a directory, and
  the decisions board can be built at all.
- Decisions become citable. `BT-ADR-0013` is unambiguous in a commit message, a
  chat, or another project's record, in a way a bare `BT-ADR-0013` never was.
- **One id grammar, not two.** Namespacing removes the separate cross-project
  syntax a repo-local scheme would have needed, and with it a class of "which
  form do I write here?" mistakes.
- **The lint's reference rule is BT-ADR-0013's, unchanged**, because "only
  own-namespace ids are references" is a string comparison on a namespaced id.
  It was a heuristic without one.
- Decisions and stories now work the same way - directory is truth, frontmatter
  mirrors, ids come from a locked counter, a derived list carries the order. One
  set of primitives gains a second consumer rather than a second implementation,
  and every corruption case already found the hard way for stories is already
  fixed for decisions.
- Supersession becomes a graph rather than a sentence, so an overturned decision
  says so on its own card instead of relying on a reader knowing.
- **Cost: a record's path changes when its status does**, so a link by path can
  break. Mitigated by the id being the citation - `BT-ADR-0013` survives every
  move - but prose that links by path must be swept when a record moves.
- **Cost: filenames get longer**, and `<NS>-ADR-` repeats in a directory where
  the namespace is constant. Accepted: the redundancy is only redundant *in
  situ*, and ids matter most once they have left the directory.
- **Cost: writing a record gains steps.** It needs an id, a frontmatter block
  and the right directory, and getting any of them wrong fails CI. The template
  and a generator absorb most of it; the rest is the price of the corpus being
  readable.
- **Cost: two more files to keep honest.** `proposed.md` and `.next-id` can be
  hand-edited into a state the lint fails on. They self-heal on the next
  mutation, but a project where nobody runs a mutating command drifts until CI
  says so.
- Two branches that each allocate an id will conflict on `.next-id` - by design,
  and the trade BT-ADR-0011 already accepted. The floor guard means the loser of the
  merge gets a fresh id rather than a silent duplicate.
- The tracker namespace is now load-bearing for two record kinds. Renaming one,
  or two projects colliding on one, breaks decisions as well as stories. The
  registry is the single place that is decided, which is the right number.

## Amendment - 2026-09-14 (BT-155)

Four corrections found by review. None changes the decision; each fixes a
statement that would mislead an implementer.

**1. `accepted` is not terminal.** The Decision says "`proposed` is the only
non-terminal status. The other four are outcomes" - written about why one
ordered list suffices, but read as a transition rule it forbids the
`accepted → deprecated` and `accepted → superseded` moves BT-ADR-0017 defines.
Read it as: **`proposed` and `accepted` are the non-terminal statuses; only
`proposed` needs an ordered list.**

**2. The lint's failure kinds have a precedence rule.** "A record with no
frontmatter block" and "missing or unparseable `status`/`date`" are listed
separately, so a lint emitting every applicable finding would report three per
unfrontmattered record. **A record with no frontmatter block yields one finding
and suppresses the per-key checks.** This is what BT-130's "13 failures"
acceptance criterion assumes.

**3. `stories:` is exempt from resolution checking**, though the lint section
claims BT-ADR-0013's rule transfers unchanged. The reason is structural: a
project's decisions and its stories need not share a checkout - this gem's
stories live in the parent repo while its decisions live here, so this
record's own `stories:` key cannot be resolved from the gem alone. Own-namespace
ids in `supersedes`/`superseded_by` are checked; `stories:` is recorded, not
resolved.

**4. The `ADR` token is justified by the wrong example.** The Decision claims
`BT-0014` and story `BT-14` would collide. `Core#format_id` is `%03d`, so story
14 is `BT-014` - textually distinct. The token is still required: a four-digit
decision id and a three-digit story id collide for real at id ≥ 1000, and
`BT-1000` is ambiguous without it.
