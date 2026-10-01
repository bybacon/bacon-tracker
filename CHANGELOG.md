# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), [Semantic Versioning](https://semver.org/).

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
