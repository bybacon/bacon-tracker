# Contributing to bacon-tracker

## Development setup

```bash
git clone https://github.com/bybacon/bacon-tracker
cd bacon-tracker
bundle install
bundle exec rspec               # Ruby test suite
node --test spec/js/*.test.js   # JavaScript unit tests (needs Node; the board
                                # client lives in lib/bacon_tracker/assets/)
```

Requires Ruby >= 3.3 (CI runs 3.3, 3.4 and 4.0 on Ubuntu and macOS). The JS tests need Node (any recent version); CI runs them on Node 20. See [docs/testing.md](docs/testing.md) for what's covered and where to add tests, and [examples/demo/](examples/demo/) for a board you can boot to try changes by hand.

## Working on a change

- **Branch first.** Create a feature branch off `main`.
- **Tests are the documentation.** Add or update specs for any behaviour change. The suite (`bundle exec rspec`) must be green. Specs live in `spec/`.
- **Keep the error boundary.** `Core` methods reachable from the web API (`set_stage`, `update_story`, `backlog_reorder`, `create_story`, `toggle_subtask`, `delete_story`, `set_status`, `create_decision`, `proposed_reorder`, `render_page`, `docs_file!`) must raise `ArgumentError` (the server turns that into a 400) - never call `abort` there. Only the Rake-facing wrappers (`commit`, `start`, `done`, `create`, and `transition_decision` for the `decision:*` tasks) may `abort`. See [BT-ADR-0005](docs/decisions/accepted/BT-ADR-0005-core-error-handling-boundary.md).
- **Read the ADRs.** `docs/decisions/` records the design decisions (files-as-state, sequential IDs, dual single/dashboard modes, the field grammar). New work should fit those or amend the relevant ADR.
- **Match the surrounding style.** Simplicity over cleverness.

## Submitting

Open a pull request against `main` with a clear description of the change and why; the pull request template walks you through it.

## Reporting bugs / requesting features

Open a [GitHub issue](https://github.com/bybacon/bacon-tracker/issues). For security issues, see [SECURITY.md](SECURITY.md) instead.

## Releasing

Maintainers: [docs/releasing.md](docs/releasing.md).
