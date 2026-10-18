---
id: BT-186
type: bug
status: icebox
---

Title: An operator should not get a red CI run from a backlog line that `rake story:commit` wrote

**Currently:**
`rake story:commit[ID]` adds the story to `backlog.md` with a title made from the filename (`backlog_add` → `humanize_slug`, lib/bacon_tracker.rb:552). For a chore filed as `WTM-087-an_external_check_watches_uptime_kuma.md` the line reads:

    - WTM-087 an_external_check_watches_uptime_kuma

The estate's tracker lint (`.github-private` `convention-lints/lint_tracker.py:254`) compares every backlog line against the story's in-file title (`Title:` for a `.md`, `Feature:` for a `.feature`) and fails:

    docs/tracker/backlog.md:1: title does not match WTM-087-an_external_check_watches_uptime_kuma.md
        listed:   an_external_check_watches_uptime_kuma
        story:    The operator should hear about it when Uptime Kuma itself goes down

`rake story:lint` does not compare titles, so it reports "Backlog is clean" on the same tree. The local check passes and CI fails.

Two details make it worse:
- `humanize_slug` only replaces `-`, so an underscore slug (`story:chore` writes those) keeps its underscores.
- The gem already has the right helper: `story_title(body, ext)` (lib/bacon_tracker.rb:423), whose comment explains why the slug is the wrong source (it loses umlauts, dots and case). `story:edit title=...` already writes the in-file title to the backlog line (line 2007). Only `story:commit` takes the slug.

**Expected:**
- `story:commit` writes the story's in-file title to `backlog.md`, the same way `story:edit` does. It falls back to the humanized slug only when the title line is missing or blank, which is what `story_title`'s nil contract is for.
- `story:lint` reports a backlog line whose title does not match the story's in-file title, as the CI lint does. Local and CI agree on the same tree.

**STEPS TO REPRODUCE:**
1. In a repo on bacon-tracker 1.1.0: `rake "story:chore[Anything]"`, then set the file's `Title:` line to a sentence ("The operator should …").
2. `rake "story:commit[NS-NNN]"`. backlog.md gets the slug, not the sentence.
3. `rake story:lint` → clean.
4. Push. The shared `conventions` job fails with "title does not match".

**REFERENCE:**
Found in WTM PR #184 (2026-10-16). CI run 38953486751, job 117151525760, failed on exactly this. It was fixed by hand in the PR's second commit (`ac648da`).
