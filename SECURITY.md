# Security Policy

## Scope

bacon-tracker is a local developer tool: the web board binds to `localhost` only and stores state as plain files in your own repository. It is not intended to be exposed on a network or run as a multi-user service.

In scope: anything a web page you visit, or a file a collaborator commits to your repository (a story, a doc page, a decision record), can do through the board - for example script injection through rendered markdown, or reaching files outside the tracked directories.

## Supported versions

Security fixes land in the latest 1.x release.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Instead, email **alex@aberger.me** with:

- a description of the issue and its impact,
- steps to reproduce (a minimal example if possible),
- the gem version (`gem list bacon-tracker`) and Ruby version.

You'll get an acknowledgement, and a fix or mitigation will be released as a patch version with credit in the changelog (unless you prefer to stay anonymous).
