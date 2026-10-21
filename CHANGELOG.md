# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- `rake story:commit` (and every other path that adds a line to `backlog.md`) writes the story's own title to the line, the same one the board shows, instead of the humanized filename slug. The slug is the fallback only when the file has neither a title line nor an opening heading. Retitling a committed story rewrites its line even when the filename does not change. `stats.next_task` follows.
- `rake story:lint` reports a `backlog.md` line whose title is not the story's (`title-drift`), on the line in `backlog.md`, and fails on it - the same comparison the shared CI lint makes, so the local check and CI agree on the same tree.
- A story created from a `_template.md` or `_template.feature` that starts with a header block of its own (`id`, `type`, `status` with a placeholder id) now has exactly one header and the title as typed. It used to carry both headers, the template's placeholder id and the template's placeholder title; the typed title reached only the filename. The title is filled into the template's first `Title:`/`Feature:` line wherever it sits, and a template without one gets the line added. `rake story:lint` points out such a template (`template-header`) as a notice, so the project can drop the block.
- `rake story:feature|bug|chore` with an unknown `size=` (say `XS`) is refused before a story is created, like the API and the board already were. It used to create the story, spend its number, and only then report "could not set fields", leaving an unsized story behind. One list of sizes (`S`, `M`, `L`) now backs creating, editing, showing and linting.
- `rake story:lint` reports a story whose file carries a size the tracker does not know (`unknown-size`), naming the story and its `size:` line. It is a notice, not a failure: the board shows such a story without a size, and old files are not made to be swept. With `LINT_FORMAT=github` it is a `::notice` annotation.
- A bug or chore with no `Title:` line that opens with a markdown heading now takes the heading as its title on the board, the dashboard and the API, the way decision records do. It used to fall back to the humanized filename slug, which loses dashes, punctuation, capitals and umlauts ("# Fix the Ä-key — today" showed as "fix the ae key today"). Retitling such a story rewrites the heading. The slug remains the fallback when there is neither.

## [1.1.0] - 2026-10-01

### Changed

- Filename slugs spell out `ä`, `ö`, `ü`, `ß` as `ae`, `oe`, `ue`, `ss` and drop accents from other letters, so "Datenschutzerklärung" becomes `datenschutzerklaerung` instead of `datenschutzerkl-rung`. Existing files keep their names until the story is retitled.
- A title with nothing the slug rule keeps (all-CJK, all-punctuation) now slugs to `non-latin-REPLACE-ME` instead of `untitled`, for story files, decision records and dashboard project slugs alike. The dashboard used to get an empty project slug in that case.

### Fixed

- Story titles on the board and in the API now come from the in-file `Title:`/`Feature:` line, so umlauts, dots and capitals survive. They were humanized from the filename slug, which keeps only ASCII letters and digits ("Datenschutzerklärung" showed as "datenschutzerkl rung", "bybacon.com" as "bybacon com"). The slug remains the fallback when the line is missing.

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
