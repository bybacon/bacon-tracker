# Troubleshooting

Problems the tracker reports about *itself* - drift, duplicate IDs, stale blockers - are [lint](linting.md)'s department. This page is the operational failures: the server, the CLI, and installing the gem.

## The board

### The server exits with a Puma stack trace

Almost always the port is taken - often by a tracker server you forgot was running. The trace mentions `Puma::Single#run` and says nothing useful.

```bash
lsof -nP -iTCP:4567 -sTCP:LISTEN     # what is holding it
tracker-dashboard --dashboard dashboard.md --port 4599
```

Note the flag: `tracker-dashboard` takes `--port`. The `PORT` environment variable is read only by the rake servers (`rake story:server` and `rake story:dashboard_server`), not by `tracker-dashboard` - setting `PORT` for it does nothing, and the server starts on 4567 regardless.

### The board returns 403 or refuses the request

The server binds to localhost and accepts `localhost`, `127.0.0.1` and `::1` only. Reaching it by machine name, LAN address or through a proxy fails host authorization. Changes (`POST`/`PUT`/`DELETE`) sent from a page on another origin are refused too (`cross-origin request rejected`). This is deliberate: the API can move and delete files, so it is not something to expose. Use an SSH tunnel if you need it from elsewhere.

### The board is empty, or a project shows all zeros

The tracker directory it points at has no story files, or `path:` in `dashboard.md` points somewhere that does not exist. `path:` is the **project** directory; the stories are expected in `<path>/tracker` unless a `tracker:` key says otherwise. An absent or empty
directory is not an error - the tracker reports zeros rather than failing, so a typo in a path looks exactly like a project nobody has started. Check every path at once (run it next to `dashboard.md`, since relative paths are resolved from there):

```bash
grep '^path:' dashboard.md | sed 's/^path: *//' | while read -r p; do
  p=$(eval echo "$p")                       # dashboard.md may use ~
  if [ -d "$p/tracker" ] || [ -f "$p/backlog.md" ]; then echo "ok       $p"; else echo "MISSING  $p"; fi
done
```

A project that sets `tracker:` keeps its stories elsewhere, so check that directory by hand. The server also prints a warning when a `tracker:` or `docs:` key names a directory that doesn't exist.

### Reveal or "open in editor" says "no launcher found"

The server found nothing to open files with. On macOS and Windows the system launcher is always there; on Linux it uses `xdg-open`, which comes with most desktops (package `xdg-utils`). Install it, or set `BACON_EDITOR` for "open in editor" - for example `BACON_EDITOR="code -w" tracker-dashboard` - and restart the server. The board shows the reason instead of pretending it worked.

### Reveal does nothing on Linux

`xdg-open` can't select a file the way Finder or Explorer can, so reveal opens the folder that contains the file in your default file manager. If nothing appears at all, run `xdg-open .` in a terminal: if that does nothing either, your desktop has no default handler for folders, which is a desktop setting rather than something bacon-tracker controls.

## The CLI

### `No project with namespace 'X'. Available: ...`

`NS=` does not match any `namespace:` in `dashboard.md`. The message lists what is available - the namespace is the one chosen at `tracker-init`, and it must match the ID prefix on the story files.

### `zsh: no matches found: story:feature[...]`

zsh (the default shell on macOS) reads `[ ]` as a glob pattern and gives up before rake runs. Quote the task, or use `noglob`:

```bash
NS=APP rake "story:feature[My first story]"
NS=APP noglob rake story:commit[APP-001]      # also works when there are no spaces
```

### `Don't know how to build task 'story:lint'`

Usually `NS` is unset. In a dashboard setup the story tasks are installed for one project at a time, so without `NS` only `story:dashboard_server` exists - the Rakefile is fine, and `rake -T` shows the difference:

```console
$ rake -T
rake story:dashboard_server   # ...and nothing else

$ NS=APP rake -T
rake story:bug[title]         # all of them
rake story:chore[title]
...
```

Failing that, `rake` is running somewhere without a `Rakefile` that loads bacon-tracker: in a dashboard setup, run from the directory holding `dashboard.md` and `Rakefile`, not from inside the project.

### `Expected field=value ..., got: "then logout"`

Rake splits bracket arguments on commas, so a title containing one is split too - and the second half is then read as a field assignment:

```console
$ NS=APP rake "story:chore[Fix login, then logout]"
Expected field=value (one of title, body, size, assignee, blocked_by,
linked_to), got: "then logout"
```

Nothing is written; the task refuses rather than creating a half-titled story. Quote the title so rake sees one argument (`'Fix login, then logout'`), or set it afterwards with `story:edit`. The same split is what lets `blocked_by=A,B` work - ID lists are re-stitched, prose is not.

A rake `body=` is one shell line: `\n` is consumed by rake's own parser before the gem sees it, so multi-line bodies belong in `/tracker`, the web UI or your editor.

### `tracker-init` refuses: namespace already registered

Another project in `dashboard.md` claims that namespace. Namespaces must be unique per dashboard - IDs carry no other scope, so two projects sharing one would produce two different `APP-004`s.

## Installing

### `gem install` fails with a permissions error

You're installing into the system Ruby, which belongs to the OS. Use a Ruby version manager (rbenv, chruby, asdf, mise) so gems install into a Ruby you own, or install for your user only:

```bash
gem install --user-install bacon-tracker
```

With `--user-install`, make sure the user gem `bin` directory (`ruby -e 'puts Gem.user_dir'` + `/bin`) is on your `PATH`, or `tracker-init` and `tracker-dashboard` won't be found. bacon-tracker needs Ruby 3.3 or newer.

### A fix is on `main` but not in the gem

The gem on rubygems.org is built from a release tag, not from `main`. A fix merged since the last release isn't in `gem install bacon-tracker` until the next version ships - check the [CHANGELOG](https://github.com/bybacon/bacon-tracker/blob/main/CHANGELOG.md) and the version you have:

```bash
gem list bacon-tracker            # or: bundle list | grep bacon-tracker
```

If you need it sooner, point a `Gemfile` at the repository: `gem "bacon-tracker", github: "bybacon/bacon-tracker"`.

## Recovering

Everything is files in git, so ordinary git tools work. To see a story's whole life, including the moves:

```bash
git log --follow -- path/to/APP-001-*.md
```

To undo a bad move, move the file back and correct `status:` - or `git revert` the commit. There is no separate state to repair afterwards.
