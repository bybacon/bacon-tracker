# Releasing

Maintainer runbook. Nothing here is needed to *use* bacon-tracker.

Pushing a `v*` tag runs the publish workflow (`.github/workflows/publish.yml`). It publishes the gem to RubyGems and creates the GitHub Release, and only when all of these hold:

- the full spec suite passes,
- the tagged commit is on `main`,
- the tag matches `BaconTracker::VERSION`,
- `CHANGELOG.md` has a dated entry for that version: `## [1.2.3] - YYYY-MM-DD`.

The release notes are that changelog entry, with a footer that adds the upgrade command and links to the diff since the previous tag and to the changelog. The workflow never runs on a fork.

Write the entry for someone skimming the release, not for the next maintainer:

- **Open with a one- or two-sentence summary** under the version line: what changed, and who should upgrade. Its first sentence becomes the release title (`v1.1.2 - Docs pages load again`), so keep that sentence short. Without a summary the title is just the tag.
- **Lead every bullet with a bold sentence** that says what the user sees now. The detail - the old behaviour, the cause, the edge cases - follows in plain text.

## One-time setup

1. **Trusted publisher on rubygems.org.** The workflow authenticates with [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/), so no API key is stored anywhere. On rubygems.org, open the gem's Ownership page (or, before the first release, your profile's pending trusted publishers) and add: owner `bybacon`, repository `bacon-tracker`, workflow `publish.yml`, environment `rubygems`.
2. **The `rubygems` environment on GitHub.** The publishing job runs in a deployment environment called `rubygems`. In the repository's Settings, under Environments, add yourself as a required reviewer and limit it to `v*` tags. Every release then waits for your approval before anything is pushed.

## Checklist

- [ ] All specs pass: `bundle exec rspec` and `node --test spec/js/*.test.js`
- [ ] Version bumped: `bundle exec rake version:patch` (or `version:minor` / `version:major`), which updates `lib/bacon_tracker/version.rb`
- [ ] `CHANGELOG.md` entry dated (`## [<version>] - <today>`), with a summary and bold-led bullets
- [ ] Changes committed and merged to `main`

## Release

```bash
git switch main && git pull
bundle exec rake version:release
```

This tags `v<current version>` and pushes the tag, and refuses to run on a dirty working tree. Then approve the `rubygems` deployment on the workflow run. The gem appears on RubyGems and the GitHub Release is created from the changelog.

If a check fails, nothing was published. Fix the cause, delete the tag (`git push --delete origin v<version>` and `git tag -d v<version>`), and tag again.
