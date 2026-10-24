# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/).


## [1.1.2] - 2026-10-23

Docs pages load again. Upgrade if you use the docs browser.

### Fixed

- **Docs pages no longer break after a code block.** Every docs page and decision record after the first one with a fenced code block showed "could not load" until the server restarted. Code blocks now render plain, without a syntax highlighter, which is how the page already showed them. Cause: kramdown required Rouge to highlight the block whenever Rouge was installed, and Rouge loaded a second copy of `strscan`, which broke every markdown render after it.

## [1.1.1] - 2026-10-21

Titles stay true and bad sizes are caught early. Backlog lines, templated stories and headed bugs and chores now carry the title you typed, and an unknown size is refused before it spends a story number. Upgrade if you keep a `backlog.md`, use story templates, or set sizes from rake.

### Fixed

- **Backlog lines use the story's real title.** `rake story:commit`, and every other path that adds a line to `backlog.md`, writes the title the board shows instead of the humanized filename slug. Retitling a committed story rewrites its line even when the filename does not change, and `stats.next_task` follows. The slug is the fallback only when the file has neither a title line nor an opening heading.
- **`story:lint` catches backlog lines that drift.** A `backlog.md` line whose title is not the story's is reported as `title-drift`, on that line, and fails the lint - the same comparison the shared CI lint makes, so the local check and CI agree on the same tree.
- **A story made from a template with its own header gets one header and the typed title.** A `_template.md` or `_template.feature` that starts with a header block of its own (`id`, `type`, `status` with a placeholder id) used to leave the story with both headers, the placeholder id and the placeholder title; the typed title reached only the filename. The title is now filled into the template's first `Title:`/`Feature:` line wherever it sits, and a template without one gets the line added. `rake story:lint` points out such a template (`template-header`) as a notice, so the project can drop the block.
- **An unknown size is refused before a story is created.** `rake story:feature|bug|chore` with, say, `size=XS` used to create the story, spend its number, and only then report "could not set fields", leaving an unsized story behind. It is now refused up front, like the API and the board already did. One list of sizes (`S`, `M`, `L`) backs creating, editing, showing and linting.
- **`story:lint` points out sizes the tracker does not know.** A story whose file carries an unknown size is reported as `unknown-size`, naming the story and its `size:` line. It is a notice, not a failure: the board shows such a story without a size, and old files are not made to be swept. With `LINT_FORMAT=github` it is a `::notice` annotation.
- **Bugs and chores without a `Title:` line take their heading as title.** A bug or chore that opens with a markdown heading now shows that heading on the board, the dashboard and the API, the way decision records do. It used to fall back to the humanized filename slug, which loses dashes, punctuation, capitals and umlauts ("# Fix the Ä-key — today" showed as "fix the ae key today"). Retitling such a story rewrites the heading. The slug remains the fallback when there is neither.

## [1.1.0] - 2026-10-01

Titles with umlauts and accents come through intact. Upgrade if you write titles outside plain ASCII.

### Changed

- **Filenames spell out umlauts instead of dropping them.** Slugs write `ä`, `ö`, `ü`, `ß` as `ae`, `oe`, `ue`, `ss` and drop accents from other letters, so "Datenschutzerklärung" becomes `datenschutzerklaerung` instead of `datenschutzerkl-rung`. Existing files keep their names until the story is retitled.
- **A title the slug rule cannot spell gets a placeholder you can spot.** A title with nothing the slug rule keeps (all-CJK, all-punctuation) now slugs to `non-latin-REPLACE-ME` instead of `untitled`, for story files, decision records and dashboard project slugs alike. The dashboard used to get an empty project slug in that case.

### Fixed

- **The board and the API show the title you typed.** Story titles now come from the in-file `Title:`/`Feature:` line, so umlauts, dots and capitals survive. They were humanized from the filename slug, which keeps only ASCII letters and digits ("Datenschutzerklärung" showed as "datenschutzerkl rung", "bybacon.com" as "bybacon com"). The slug remains the fallback when the line is missing.

## [1.0.0] - 2026-09-25

First public release.

### Added

- Stories, bugs and chores as Markdown and Gherkin files in four stage directories: icebox, backlog, started, done. `backlog.md` holds the priority order.
- Rake tasks to create, commit, start, finish, edit and lint stories, with sequential ids issued under a file lock.
- A local web board with drag and drop, inline create and edit, subtask checklists, relationship badges and a detail view. Stories can also be moved from the edit form and operated by keyboard.
- A dashboard across several projects, driven by one `dashboard.md`.
- Decision records (ADRs) with their own ids, a status board, `decision:*` Rake tasks and a lint.
- A docs browser for a project's `docs/` tree, with search, backlinks and a README/CHANGELOG front page.
- `tracker-init` to scaffold a project, and an optional `/tracker` command for Claude Code.
- `story:lint` output as GitHub Actions annotations with `LINT_FORMAT=github`.
- Reveal and open-in-editor on macOS, Windows and Linux (`xdg-open`), with `BACON_EDITOR` for a custom editor.

### Security

- Markdown rendered by the docs and decisions surfaces is sanitised: raw HTML, event handlers and non-http(s)/mailto links are removed.
- State-changing requests from another origin are rejected, the Host header is pinned to localhost, pages cannot be framed, and request bodies are capped.
