---
status: accepted
date: 2026-08-16
stories: [BT-048, BT-052]
---

# Web-reachable Core methods raise; only Rake-facing wrappers abort

- Date: 2026-08-16
- Related stories: BT-048…BT-052 (corruption-class review)

## Status

Accepted

## Context

`Core` is driven by two front ends with opposite failure semantics:

- The **Rake tasks** are a CLI. On bad input the right behavior is to print a
  message and exit non-zero - `abort`.
- The **Sinatra server** serves the web UI. A `Kernel#abort` inside a request
  would kill the whole process; the right behavior is to return HTTP 400.

If `Core` methods called `abort` directly, the server could not turn a bad
request into a 400 without the process dying, and a single malformed edit could
take down every project on the dashboard.

Options considered:
1. Let each `Core` method decide how to fail (mixed `abort`/`raise`).
2. Draw one boundary: methods the web API can reach never `abort`; they raise a
   typed error, and the thin Rake wrappers translate it to `abort`.

## Decision

Option 2. Methods reachable from the HTTP API - `set_stage`, `update_story`,
`backlog_reorder`, `create_story`, `toggle_subtask`, and `delete_story` - raise
`ArgumentError` on invalid input and never call `abort`. The server rescues
`ArgumentError` and returns 400. The Rake-facing wrappers - `commit`, `start`,
`done`, `create` - rescue `ArgumentError` and `abort` with the message. This is
the "Key invariant" recorded in CLAUDE.md.

## Consequences

- Easier: one malformed request is a 400, not a downed server; the same
  validation serves both front ends with front-end-appropriate failure.
- Harder: a contributor adding a new mutation must know which side of the line
  it sits on. A web-reachable method that `abort`s is a latent
  process-kill bug that won't show up in Rake-only testing.
- Enforcement is by convention + specs, not the type system. If the surface
  grows, consider a lint or a shared `raise`-only base to make violations loud.
- Reconsider if a non-HTTP long-lived caller ever appears; the boundary is
  "anything that must not exit the process," currently synonymous with "web."

## Amendment - 2026-09-25 (BT-179)

The surface has grown; the boundary has not moved. Also web-reachable, and
therefore raise-only: `set_status`, `create_decision`, `proposed_reorder`,
`render_page` and `docs_file!`. `transition_decision` is the Rake-side wrapper
for decisions and is the only one of those allowed to `abort`. The invariant is
now recorded in `CONTRIBUTING.md` rather than `CLAUDE.md`, which is not part of
the published repository.
