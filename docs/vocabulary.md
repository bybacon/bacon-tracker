# Vocabulary

bacon-tracker borrows almost nothing from the tools people arrive from, so the words that come with those tools - ticket, card, column, sprint - describe things this tracker doesn't have. Using them isn't only imprecise: it smuggles in a mental model where a story is a record in somebody's database rather than a file in your repo.

This page fixes the terms. It's short on purpose. The flow itself is in [flow.md](flow.md).

## The work item is a **story**

A story is a plain file: Gherkin (`.feature`) for features, Markdown (`.md`) for bugs and chores. That's the noun, for all three types. A bug is a story; a chore is a story.

Not a *ticket* (there is no queue, no service desk, no requester), not an *issue* (that's GitHub's word for something else, and a tracker story is not a GitHub issue), not a *task* (see **subtask** below, which is a different thing and would collide), and not a *card* - which has its own meaning:

> **card** - the board's *rendering* of a story. A card is what you drag; a
> story is what moves. "Click the card" is right. "Write a card" is not - you
> write a story, and the board happens to draw it as a card.

The same split applies to **board**: the board is a view of the directories. It is the *tracker board*, or just the board - not a *kanban board*. Nothing here implements kanban (no WIP limits enforced in software, no pull signals, no classes of service). It's four directories drawn in four columns.

## The three **types**

`feature`, `bug`, `chore` - singular when you name the type, plural when you name the directory it lives in (`features/`, `bugs/`, `chores/`). These are the only three, and the directory names are the only ones the tracker scans.

## Where a story is: **stage**

The stage is the directory the file sits in: `1_icebox/`, `2_backlog/`, `3_started/`, `4_done/`. The directory is authoritative - it *is* the state, not a cache of it.

Two words that are not synonyms for stage:

- **column** - the board's rendering of a stage, the way *card* renders a story. Fine when you mean the UI.
- **status** - the frontmatter field that *mirrors* the stage. It's a convenience for reading a file on its own, and it can drift; `rake story:lint` reports it when it does. When they disagree, the directory wins.

**icebox** and **backlog** are stages, not moods. The icebox is everything you might do, the backlog is the 3–7 things you will do next. Stack-ranked. Neither is a *sprint* - there are no sprints, no iterations, and no dates.

## The workflow **verbs**

The transitions have names, and they're the same in every interface:

| Verb | Moves | Means |
|---|---|---|
| `commit` | icebox → backlog | deciding to do it |
| `start` | backlog → started | beginning work |
| `done` | any → done | it shipped |

**`commit` is the one to watch.** It collides with git, and the collision is worth a half-second of care every time: "commit APP-042" moves a story into the backlog. "commit the story file" writes it to git history. When both are in play, say which.

Stories are **moved**, not *assigned* or *transitioned*. Nothing is *closed* or *resolved* - it's **done**, and done is append-only: never deleted, never reopened.

## Fields on a story

- **id** - `<NS>-NNN`, e.g. `APP-042`. The namespace prefix is the project's.
- **size** - `S`, `M`, or `L`. Not points, not estimates, not hours.
- **assignee** - initials. There is no "owner" or "reporter".
- **subtask** - a `- [ ]` checklist line in a story's body. The board counts and ticks these. A subtask is *not* a child story. Stories have no hierarchy, no epics, and no parents.

## Relationships

Two fields, each with a derived reverse the board renders but nobody types:

| You write | Derived on the other story | Means |
|---|---|---|
| `blocked_by` | `blocks` | this story waits on that one |
| `linked_to` | `linked_from` | related, no dependency - a "see also" |

A relationship is stored on exactly one side. The tracker computes the other end across the whole board. So "APP-002 blocks APP-003" and "APP-003 is blocked by APP-002" describe one fact, written once.

`blocked_by` may also name something that isn't a story at all - an upstream release, another team's work. That's deliberate, and lint leaves it alone.

## Naming things that don't exist here

If you find yourself reaching for one of these, the tracker doesn't have it, and the absence is usually the point:

*epic, parent, subtask-as-story, sprint, iteration, velocity, story points, priority field, swimlane, workflow state, assignee queue, backlog grooming, triage, reopen, close, archive.*

Priority in particular: there is no priority field, because a field lets six things be "critical" at once. Position in `backlog.md` is the priority.
