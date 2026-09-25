# The bacon flow

bacon-tracker is a small tool wrapped around an opinionated way of working. The tool is four directories and a text file; the flow is what makes them worth having. This document names the opinions so they can be followed - or argued with - deliberately. It also uses the project's words precisely; [vocabulary.md](vocabulary.md) defines them.

The short version:

1. **Stories are files in git.** The tracker state is source, versioned with the code.
2. **The icebox is cheap, the backlog is a promise.** Capture everything; commit to 3–7 things.
3. **Pull one story at a time.** Finish it before starting the next.
4. **Done is append-only.** Never deleted, never reopened.

Everything else follows from these four.

---

## Stories are files

A story is a plain file - Gherkin for features, Markdown for bugs and chores - with a few frontmatter fields (`id`, `type`, `status`, optionally `size`, `assignee`, `blocked_by`, `linked_to`). Its stage is the directory it sits in: `1_icebox/`, `2_backlog/`, `3_started/`, `4_done/`. Moving work forward is moving a file. The body can carry a checklist - `- [ ]` lines are subtasks the board counts and ticks off - so a story tracks its own progress without splintering into a dozen tiny ones.

Because the state is files in the repo:

- **Stories ship with the code.** The commit that finishes a feature also moves its story to done. The reviewer sees criteria and implementation in one diff; `git log` on the story file is its complete lifecycle.
- **History is free.** Decisions, timings, and reasoning are recoverable with `grep` and `git blame` - no export, no vendor, no expiry.
- **Every interface is a view.** The rake CLI, the tracker board, the `/tracker` Claude Code command, and your text editor all read and write the same files. Pick by taste, mix freely. There is no "real" interface to hold wrong: an edit from any of them is just an edit, and the tools reconcile (`backlog.md` membership self-heals from the `2_backlog/` directory; `rake story:lint` reports drift, duplicate IDs, a stale `.next-id`, `status:` fields that disagree with their directory, and relationships that have gone stale - a `blocked_by` whose blocker already shipped, a reference to a story that doesn't exist, two stories waiting on each other).

## The icebox is cheap, the backlog is a promise

Two piles with opposite requirements, kept apart on purpose:

- **Icebox** - everything you *might* do. Capture must be free: an idea arrives, you file it in thirty seconds, no estimate, no debate. Nothing here is owed to anyone, which also means deleting from the icebox costs nothing. Sweep it now and then; ideas worth doing come back.
- **Backlog** - only what you *will* do next. 3–7 stories, stack-ranked in `backlog.md`, top line first. Moving a story from icebox to backlog (`story:commit`) is the decision - an act of commitment, made by choosing what the story goes above.

Position is priority. There are no priority fields: a field lets six things be "critical" simultaneously, which decides nothing. A stack rank permits no ties - something is first, and the top line is always the answer to "what next?".

A backlog you can read in ten seconds is a plan. If it's growing past seven, the honest fix is moving things back to the icebox, not reading faster.

## Pull one story at a time

When you finish a story, pull the *top* of the backlog (`story:start`) - the prioritization already happened; don't re-litigate it at pull time. The sweet spot is **one story started, two at most** (two exists because one story blocked plus one moving is a legitimate state - that's what `blocked_by` is for).

The dashboard enforces the opinion in color: green border at 1–2 started, amber at 3+, red when the backlog has committed work but nothing is started. Amber means attention is split and nothing is finishing. Red usually means the real work has gone off the books - if it's worth an afternoon, it's worth a thirty-second story file.

Unfinished work is inventory: cost paid, value undelivered, rotting as the branch drifts. Finishing one story beats advancing three.

## Done is append-only

`4_done/` only grows. Nothing is deleted, and done stories are never reopened - when shipped work breaks later, that's a new bug with a new ID pointing at the old story. The record stays trustworthy precisely because everyone knows it doesn't move.

What the directory becomes after a year: the changelog (a walk through recent done stories), the retro agenda (what actually moved), the onboarding doc (read it in ID order - the product's decisions in the order they were made), and the answer to every "when did we change X, and why?".

One duty at close time: if the implementation drifted from the story - scope cut, approach changed - update the file *before* moving it to done. A done story that describes the intention rather than what shipped is a record that lies.

## The flow beyond code

None of this is specific to software. The flow fits any stream of work you want to capture cheaply, commit to honestly, finish deliberately, and remember permanently. A blog's editorial pipeline, for example, maps straight onto the same directories: post ideas in the icebox, scheduled drafts in the backlog, published posts in done.

The tool is a few hundred lines of Ruby around `mv`. The flow is the product.
