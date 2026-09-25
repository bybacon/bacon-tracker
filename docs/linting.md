# Linting the tracker

```bash
rake story:lint          # add NS=<namespace> in a dashboard setup
```

The tracker's state is files, which means an ordinary merge can leave it inconsistent - a backlog line whose file moved, an ID issued twice, a blocker that shipped months ago. `story:lint` is the check that says so. It exits `0` when the tracker is clean and non-zero when something is actually broken, which makes it usable as a CI gate with no wrapper.

Why each check reports what it does - and why some findings deliberately do not fail - is recorded in this project's decision record
[BT-ADR-0013](decisions/accepted/BT-ADR-0013-relationship-lint-scope-and-severity.md).

## What it checks

### Structure

| Finding | Means | Fix |
|---|---|---|
| `phantom` | `backlog.md` lists an ID with no file in a `2_backlog/` directory | Remove the line, or move the story back into `2_backlog/`. Most mutations self-heal this. |
| `unlisted` | A file sits in `2_backlog/` with no line in `backlog.md` | Add the line - position is priority, so put it where it belongs rather than at the end. |
| `duplicate` | The same ID has files in more than one stage directory | Two stages both claim the story. Decide which is true and delete the other; check `git log` for which moved last. |
| `status-drift` | A story's `status:` disagrees with the directory it is in | The directory wins. Correct the field. |
| `stale-id` | `.next-id` is not above the highest story on disk | Set it to `highest + 1`. Usually a merge that took the lower value. **Do not** let it reissue an ID. |

### Relationships

| Finding | Means | Fix |
|---|---|---|
| `stale-blocker` | A `blocked_by` names a story that is now in `4_done` | The blocker shipped and this story never got the memo. Clear it from `blocked_by`. |
| `dangling-ref` | A `blocked_by` or `linked_to` names an ID with no story file | A typo, or a story deleted from the icebox. Correct or remove it. |
| `cycle` | Stories wait on each other, directly or transitively | A deadlock: nothing in the cycle can start. Break it by deciding which one genuinely goes first. |
| `blocked-started` | A story in `3_started` has an unresolved blocker | **Reported, does not fail.** Often legitimate - see below. |

A `blocked_by` value that is not a story ID for the current namespace is left alone. Waiting on an upstream release (`sinatra-5.x`) or another team's ticket is a real use of the field, not a dangling reference.

Stories already in `4_done` are never the *subject* of a finding. Done is append-only, so their relationships are a record of what was true when the work shipped. They are still the *object* of one - that is exactly what `stale-blocker` detects.

## What fails, and what only tells you

Everything above fails the command except `blocked-started`, which prints and exits `0`:

```
  blocked-started: APP-004 is started but waits on APP-003 (2_backlog)
No integrity problems - the note above is a flow signal, not a failure.
```

One story blocked plus one moving is a legitimate state - it is the reason [the flow](flow.md) puts the started limit at two rather than one. Failing a build on a legitimate state teaches people to ignore the build.

## In CI

Set `LINT_FORMAT=github` and each finding becomes an annotation on the story file and line that caused it, so it appears in the pull request's diff rather than in a log someone has to open:

```
::error file=tracker/features/2_backlog/APP-004-notifications.feature,line=5::stale-blocker: APP-004 waits on APP-003, which is done - clear it from blocked_by
```

`blocked-started` is emitted as `::notice`, annotating without failing the check. Without the variable the output is unchanged, so local use is unaffected.

Any CI system works - it is one command:

```yaml
- run: bundle exec rake story:lint
  env:
    LINT_FORMAT: github
```

Findings with no single owning file point at `backlog.md` or `.next-id` rather than inventing a location. A duplicate ID annotates both of its files, since a pull request may contain only one of them.

## What it does not do

It does not fix anything. `backlog.md` membership self-heals during ordinary mutations because it is derivable from `2_backlog/` - but a stale `blocked_by` is not derivable, and silently removing it would discard what the author meant. Lint reports, a human decides.

## Decision records

`rake decision:lint` is the same idea for [decision records](https://github.com/bybacon/bacon-tracker#decision-records): it checks their frontmatter, that each record's `status:` matches its directory, ids, supersession links, and `proposed.md`. Integrity problems fail the command; hygiene findings print as warnings and exit `0`.
