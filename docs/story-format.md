# Story format

A story is a file. This page is the contract every interface reads and writes - the rake tasks, the board, the `/tracker` command, and your editor. Nothing else holds state, so if a tool respects what is written here it will agree with every other tool.

Terms used below (story, stage, type, subtask) are defined in [vocabulary.md](vocabulary.md).

## Where a story lives

```
tracker/
├── features/   .feature files (Gherkin)
├── bugs/       .md files
└── chores/     .md files
```

Each type directory holds the four stage directories - `1_icebox/`, `2_backlog/`, `3_started/`, `4_done/`. **The directory is the state.** Moving a story from backlog to started is moving the file. The `status:` field is a mirror for reading a file on its own, and when the two disagree the directory wins.

## Filename

```
<NAMESPACE>-<NNN>-<slug>.<ext>
APP-001-implement-user-auth.feature
```

The ID prefix is what every tool matches on. The slug is made from the title when the story is created: lowercased, each run of anything that isn't a letter or digit turned into one hyphen, trimmed at both ends (`untitled` if nothing is left). `.feature` for features, `.md` for bugs and chores. A leading `_` marks a file as not a story - `_template.feature` is skipped by every scan.

## Frontmatter

Two dialects, chosen by extension.

**`.feature` files** - comment-based header lines at the top:

```gherkin
# id: APP-001
# type: feature
# status: backlog
# size: M
# assignee: AB
# blocked_by: APP-005, APP-006
# linked_to: APP-012

Feature: Implement user auth
  Scenario: A returning user signs in
    Given ...
```

**`.md` files** - a YAML block:

```markdown
---
id: APP-002
type: bug
status: started
size: S
---

Title: Login redirect loops on expired session

## Description
...
```

The story's in-file title is its `Feature:` line (features) or `Title:` line (bugs and chores). The board shows the title made from the filename slug instead (as does the line a commit adds to `backlog.md`) - `APP-002-login-redirect-loops-on-expired-session.md` displays as "login redirect loops on expired session". Changing the title through `story:edit`, `/tracker edit` or the board's edit mode updates both: it rewrites the in-file line and renames the file. Editing the `Title:` line by hand changes only the file's content.

A `.feature` file that opens with a `---` YAML block is read as YAML too, so a
story authored by hand in the wrong dialect still parses.

## Fields

| Field | Values | Required |
|---|---|---|
| `id` | `APP-001` - namespace plus zero-padded number | yes |
| `type` | `feature` \| `bug` \| `chore` | yes |
| `status` | `icebox` \| `backlog` \| `started` \| `done` | yes |
| `size` | `S` \| `M` \| `L` | no |
| `assignee` | Initials, e.g. `AB` | no |
| `blocked_by` | Comma-separated IDs this story waits on | no |
| `linked_to` | Comma-separated IDs of related stories - a symmetric "see also" | no |

An empty value clears a field. Unknown keys are preserved but ignored. In a YAML block, `blocked_by` and `linked_to` may also be written as a YAML list (`blocked_by: [APP-005, APP-006]`); the tools write the comma form. Every value stays on one line, however long.

### Relationships have two ends, and you write one

`blocked_by` and `linked_to` live in the story's own frontmatter. Their inverses - `blocks` and `linked_from` - are **derived** across the whole board and never stored, because a file-based tracker cannot transactionally write the far side of a pair. The board renders both ends; only one file changes.

`blocked_by` may name something that is not a story at all - an upstream release, another team's ticket. That is supported, and [lint](linting.md) leaves such values alone.

## Subtasks

Any Markdown checkbox line in the **body** is a subtask:

```markdown
- [ ] wire up the endpoint
- [x] add the migration
- [ ] backfill existing rows
```

They are ordinary body text, so they work in every interface. The board shows `done/total` and its checkboxes write straight back to the file. Lines inside a fence - ``` ``` ``` in Markdown, `"""` in Gherkin - are ignored, so a checklist shown as an example is not mistaken for a real one. Features support them too. The checklist goes below the scenarios.

A subtask is not a child story. There is no hierarchy.

## backlog.md

One story per line, top line next up. Position is the priority - there is no priority field.

```markdown
- APP-003 implement user auth
- APP-007 add email notifications
- APP-001 set up CI
```

The format is `- <ID> <title>`: leading dash, single space. The stats and next-task parsers depend on it, so keep it when editing by hand. Only lines in that shape are treated as entries, so an ID mentioned in a comment or heading is not read as membership.

Hand-editing is safe. Membership self-heals from what is actually in `2_backlog/`, and [lint](linting.md) reports any drift that survives.

## .next-id

A single integer: the number the next story will get. It is consumed under a file lock and floored above the highest ID on disk, so a stale value from a merge cannot reissue an ID that already exists.

Never reuse an ID. Commit messages, branch names and `blocked_by` fields all point at IDs, and reissuing one silently repoints that history at the wrong story.
