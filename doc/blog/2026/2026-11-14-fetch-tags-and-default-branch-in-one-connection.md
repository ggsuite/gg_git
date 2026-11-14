<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Fetch tags and default branch in one connection

## Motivation

- Every git call is a process to wait for, and every fetch is a connection
  to a remote. Both add up when git is asked often.
- Making the tags of a checkout a copy of the remote's meant deleting the
  local tags and fetching them anew: three connections.
- A plain fetch leaves `origin/HEAD` as the clone recorded it, also after
  the default branch was renamed on the server. Refreshing it opened one
  more connection.
- `LastChangesHash` started one `git hash-object` per unstaged file. A tree
  with many changes was slow.
- A remote that answered with a rate limit was not asked again.

## Strategy

- Let one `git fetch` do the work of several, through options of `Fetch`.
- Ask which git is installed, and fall back to the older way if needed.
- Hand many files to one git call, and run independent calls at the same
  time.
- Wait much longer after a rate limit than after a dropped connection.
- Start fewer git processes in the test helpers and in the tests.

## Two options for Fetch

- `Fetch.get(mirrorTags: true)` adds `--prune --prune-tags --force`. A tag
  deleted on the remote is deleted, a tag moved there is moved.
- `Fetch.get(refreshDefaultBranch: true)` makes `origin/HEAD` name the
  default branch of the remote afterwards.
- With git 2.48 or newer this happens in the connection of the fetch,
  through `-c remote.origin.followRemoteHEAD=always`.
- An older git is asked with `git remote set-head origin --auto`
  afterwards. That call is retried, and its failure never fails the fetch.
- `Fetch.arguments` builds the command line for callers that run git
  through their own process runner.

## GitVersion

- `GitVersion.isAtLeast(major, minor)` tells whether the installed git is
  new enough for a feature.
- It asks `git --version` once per process and never throws. An answer it
  cannot read counts as older than every version.
- `GitVersion.fixed` and `GitVersion.unknown` are for tests.

## One git call for many files

- `LastChangesHash` hashes the unstaged files with one
  `git hash-object -- <files>` per command line full
  (`maxCommandLineLength`), not one call per file.
- A deleted file or a folder gets the empty hash without asking git. A call
  git refuses falls back to file by file. The hash values are unchanged.
- The index and the working tree are read at the same time, and so are the
  two questions of `UnstagedFiles`.
- `waitForBoth(a, b)` reports a failure only once both are through. A git
  process that still runs holds on to its working directory, and Windows
  refuses to delete it.

## Rate limits in GitRetry

- `GitRetry.isRateLimited` recognizes »rate limit«, »abuse detection«,
  »too many requests« and HTTP 429.
- Such a command is retried after `rateLimitDelay`, 60 seconds, doubled
  with every retry. A limit like this is lifted after a minute or more, and
  asking earlier only prolongs it.
- The log line says that the remote limits how often it is asked.

## Fewer git processes in tests

- `initLocalGit` checks out `main` only in a repository that was there
  before. A new one is on `main` right away.
- `commitFile` asks `git status` only when git refuses the commit; an amend
  still asks first. It commits with `maintenance.auto=false`, so no
  detached maintenance process outlives the test.
- The tests of this package take their standard repositories from the
  cached templates: 1566 git processes instead of 2830.
- Measured under Windows on 22 processors, the run with every process
  traced went from 107 s to 71 s.

## Open Points

- `refreshDefaultBranch` looks at the remote `origin` only.
- With a git older than 2.48 the default branch still costs a connection
  of its own.
- `mirrorTags` makes the tags a copy: a local tag the remote does not have
  is deleted as well.
