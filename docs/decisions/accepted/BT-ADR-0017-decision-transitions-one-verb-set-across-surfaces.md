---
status: accepted
date: 2026-09-13
deciders: [alex]
stories: [BT-135]
tags: [decisions, api, workflow]
---

# Decision transitions are one verb set over one primitive, and `supersede` takes a target and writes both sides

- Date: 2026-09-13
- Related chores: BT-135 (set_status + the four surfaces)
- Relates to: BT-ADR-0014 (the ADR contract), BT-ADR-0004 (workflow verb naming), BT-ADR-0005
  (Core error-handling boundary), BT-ADR-0013 (only own-namespace ids are references),
  BT-ADR-0011 (the lock), BT-102 (done is append-only), BT-084 (atomic writes)

## Status

Accepted

## Context

A story moves through four surfaces that all do the same thing: a drag on the
board (`PUT /api/stories/:id/stage`), a Rake task (`story:commit`,
`story:start`, `story:done`), the `/tracker` command, and a hand `git mv`. They
agree because they all funnel into `Core#set_stage(id, new_stage)`, and BT-ADR-0005
puts the validation there - the web-reachable primitive raises `ArgumentError`,
the Rake wrapper aborts.

Three properties make that easy, and **decisions have none of them**:

- **Story verbs take no arguments.** `commit BT-042` is complete. Every
  transition is identified by the target stage alone.
- **A story transition writes one record.** It is a `mv` between stage
  directories; `backlog.md` heals from the directory afterward. A decision
  transition is the same shape - a `mv` between status directories plus the
  mirrored `status:` key - until `supersede`.
- **A story transition is local.** Nothing outside the project is involved.

A decision transition breaks all three. `superseded` is meaningless without
naming *what* superseded it. BT-ADR-0014's lint **fails** an own-namespace
supersession that is asymmetric, so recording it correctly means writing
`superseded_by` on one record and `supersedes` on another - two files. And the
superseding record may be in another repository entirely: a record may adopt a decision
another project owns, and BT-ADR-0013 settled that a checkout must
not claim anything about an id it cannot resolve.

This first surfaced as a UI question - what should the board do when a card is
dragged into the `superseded` column? That was the symptom. The same gap exists
in the HTTP API, the Rake tasks and the slash command, and answering it four
times independently is how four surfaces end up disagreeing about what a
decision means.

There is already precedent for the shape of the answer. `set_stage` refuses to
move a story out of `4_done` - done is append-only (BT-102, `docs/flow.md`) -
and because the refusal lives in `Core`, the board, the API and the Rake task
all inherit it without each knowing why.

## Decision

### One verb per transition, named for the status it produces

Following BT-ADR-0004, the verbs match the vocabulary they move records into:

| verb | from → to | arguments |
|---|---|---|
| `accept` | proposed → accepted | - |
| `reject` | proposed → rejected | - |
| `deprecate` | accepted → deprecated | - |
| `supersede` | accepted → superseded | **the superseding id** |

**`accept` and `reject` also move `date`** to the day the decision took effect,
per BT-ADR-0014 - a transition is never a bare status write.

### The transition graph is forward-only

`rejected`, `deprecated` and `superseded` are terminal, and **nothing returns to
`proposed`.** Un-deciding is not a transition: an ADR is immutable, so a
reversal is a new record that supersedes the old one, exactly as a reopened
story is a new story. This is BT-102's rule carried across - and, as there, it
lives in `Core` so every surface refuses identically.

### One primitive

`Core#set_status(id, new_status, superseded_by: nil)`, web-reachable, raising
`ArgumentError` per BT-ADR-0005:

- the status is outside the five, or the record is not found → raise;
- the transition is not in the graph above → raise, with the reason;
- `new_status` is `superseded` and no target is given → raise. **A missing
  target is an error, never a silent status write** - the alternative leaves a
  record whose own frontmatter says it was superseded by nothing.
- **In-namespace target:** it must resolve, or raise. Both records are written
  under the same lock (BT-ADR-0011), atomically (BT-084), so the lint's symmetry rule
  can never observe a half-applied supersession.
- **Out-of-namespace target:** only the local side is written, and the caller is
  told so. BT-ADR-0013's rule applies unchanged - this checkout cannot resolve an id in
  another namespace, cannot write another repository, and must not pretend the
  other half exists. The reciprocal edit is that repo's own transition.
- `proposed.md` heals afterward, since membership derives from `status`.

### The four surfaces map onto it, and add nothing

- **API** - `PUT /api/decisions/:id/status`, body `{ status, superseded_by }`,
  mirroring `PUT /api/stories/:id/stage`. Validation is the primitive's; a
  missing or unresolvable target is a 400, not a 200 with a partial write.
- **Rake** - `decision:accept[BT-ADR-0009]`, `decision:reject[…]`,
  `decision:deprecate[…]`, and `decision:supersede[BT-ADR-0009,BT-ADR-0016]`.
  Only `supersede` takes a second positional argument, which is the visible
  shape of the asymmetry rather than a special case hidden inside it.
- **Command** - the slash command must *collect* the target before calling, and
  ask for it when the user says only "supersede BT-ADR-0009". It never invents
  one and never falls back to a bare status write.
- **Board** - the `superseded` column does not accept a plain drop. A drop opens
  a target picker and the transition is completed with it, or it is refused.
  This is a rendering of the primitive's rule, not a UI policy of its own.

## Consequences

- The four surfaces cannot drift, because none of them knows the rules - the
  primitive does. A fifth surface inherits them for free.
- The lint's symmetry check becomes an assertion about hand edits and merges
  rather than about the tool's own writes: an in-namespace supersession applied
  through any surface is symmetric by construction.
- **`supersede` is the first multi-record write in the codebase.** Every story
  verb touches one file. It must hold the lock across both writes and be atomic
  across them, which is a stronger requirement than BT-084 solved for single
  files, and it is the one place this design adds real risk.
- **A cross-repo supersession is permanently half-recorded** from either side's
  point of view. Accepted: it is the honest state, it matches what BT-ADR-0013 already
  decided about unresolvable ids, and the alternative is a tool that edits
  repositories it was not pointed at.
- Forward-only transitions mean a mistaken `accept` cannot be undone in place.
  Accepted, and consistent - the record is the point, and `git revert` is the
  answer for a genuine slip, the same as for a story moved by accident.
- The verbs are decision-specific, so `rake -T` grows a `decision:` namespace
  beside `story:`. Two vocabularies, deliberately: a decision is not a story,
  and sharing verb names would imply a shared lifecycle that does not exist.
- **Cost: `accept` writing `date` as well as `status` makes the primitive
  status-aware in a way `set_stage` is not.** It is the price of `date` meaning
  "took effect" rather than "was last touched".
