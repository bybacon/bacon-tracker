---
status: accepted
date: 2026-09-14
deciders: [alex]
stories: [BT-140]
tags: [docs, dependencies]
---

# Render markdown server-side with kramdown

- Date: 2026-09-14
- Related story: BT-140

## Status

Accepted

## Context

The docs surface renders pages (BT-140), which needs a markdown engine - the
first one in the gem. Three shapes were on the table: a hand-rolled renderer
(a bug farm wearing a small diff; markdown's edge cases are why engines exist),
a vendored JS renderer in the client (a large unauditable blob in assets/, and
rendering then differs between the preview and any future server-side use), or
a Ruby engine as a runtime dependency.

BT-ADR-0001 already settled the posture: this gem prefers real runtime
dependencies over vendoring or hand-rolling, provided they are maintained and
justified. The candidates: commonmarker (fast, but a native extension - a
compile step on every install), redcarpet (native, maintenance has slowed),
kramdown (pure Ruby, no extensions, long-maintained, GFM via
kramdown-parser-gfm).

## Decision

**kramdown plus kramdown-parser-gfm as runtime dependencies.** Pure Ruby keeps
`gem install` compile-free on every platform the tracker already runs on, and
GFM input gives the two things the docs corpus actually uses beyond
CommonMark: task-list checkboxes and tables. Rendering happens server-side in
`Core`, so the browser preview and anything else that ever needs HTML share one
engine and one output.

## Consequences

- Two new runtime dependencies, both pure Ruby - no native build step appears
  in the install path.
- Server-side rendering means the raw-vs-rendered choice is the endpoint's,
  and the client stays a thin consumer.
- kramdown's HTML output is unsanitized by default; pages are local files the
  user already owns, rendered same-origin on localhost - the existing trust
  model, not a new exposure. Revisit only if pages ever come from elsewhere.
- Cost: markdown fidelity is pinned to kramdown's GFM dialect; a page written
  against GitHub's renderer can differ in edge cases.

## Amendment - 2026-09-25 (BT-179)

**Rendered HTML is sanitised.** The consequence above assumed pages are files
the viewer owns. In a shared repository they are files any collaborator can
change, and the rendered HTML lands in a page that can call the write API. A
`<img onerror>` or a `javascript:` link in a teammate's page would run on the
board's origin.

`Core#render_markdown` now walks kramdown's element tree before `to_html`: raw
HTML elements, `{::nomarkdown}` and XML nodes are dropped; event-handler and
`style` attributes are removed, including ones set through attribute lists;
`href`/`src` must be relative or use http, https or mailto. GFM task-list
checkboxes, the one raw element the parser itself emits, are kept as disabled
checkboxes with no other attributes. No sanitiser gem was added: kramdown's
tree already separates what markdown produced from what an author inlined, so
an allowlist would restate the markdown decision a second time.
