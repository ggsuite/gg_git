# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What This Is

`gg_git` is a Dart package with git helper commands for repository checks
(e.g. `IsCommitted`, `IsPushed`, `ModifiedFiles`, `GitStatus`, `Commit`) and a
public test-helper library used by the other ggsuite packages.

It is **git only** — deliberately. gg's own conventions (the `#gg: ` commit
prefix, which files gg's bookkeeping owns) are *application* knowledge, not git
semantics, and live in `gg_one_core`. Do not move them down here: this package
must stay usable for anything that talks to git.

`Commit.commit` takes an optional `paths` (and `stagePaths`) pathspec. Passing
it turns the commit into `git add -- <paths>` + `git commit -m <msg> -- <paths>`
so nothing else in the working tree can ride along; `null` keeps the tree-wide
`git add .` every older caller expects. A partial commit is impossible during a
merge, rebase or cherry-pick, so the guard throws there instead of silently
falling back to committing everything.

## Commands

```bash
dart test                                    # all tests
dart test test/commands/commit_test.dart     # single file
dart analyze
dart format .
```

Use `gg` for the workflow (never plain `git commit`/`git push`):
`gg can commit` → `gg do commit -m <message>` → `gg do push`.

## Architecture

- `lib/src/base/process_runner.dart` — the `ProcessRunner` typedef of the
  whole gg family (superset signature: `workingDirectory`, `environment`,
  `runInShell`) plus `defaultProcessRunner`. Injected everywhere instead of
  each package declaring its own.
- `lib/src/base/git_snapshot.dart` — `runGit` (throw-on-non-zero unless
  `allowFailure`; `trimmed: false` when the raw stdout matters, as for the
  positional columns of `git status --porcelain`) and `captureUncommitted`
  (stash tracked + staged/unstaged + untracked into a dangling commit, tree
  left unchanged). Both are pure git, so they live here rather than in one of
  the packages that happen to use them.
- `lib/src/base/git_retry.dart` — `GitRetry` reruns a git network command
  (push, fetch, …) whose stderr shows a transient transport failure
  (`isTransient`: »closed by remote host«, »kex_exchange_identification«
  (GitHub's SSH throttling), »the remote end hung up unexpectedly«, a 5xx
  reply, a failed DNS lookup (»could not resolve host«), »connection timed
  out«, …). A rejected push, missing credentials or an unknown repository
  is never retried; a misspelled host or a blocked port is, and fails again
  after the last attempt. Four attempts by default, 5 s / 15 s / 45 s apart;
  `GitRetry.example` retries without waiting for tests. A **rate limit**
  (`isRateLimited`: »rate limit«, »abuse detection«, »too many requests«,
  HTTP 429 — GitHub's secondary rate limit, npm, pub.dev) is retried as
  well, but after `rateLimitDelay` (60 s), doubled with every retry: such a
  limit is lifted after a minute or more, and asking earlier prolongs it.
  The log line then says that the remote limits how often it is asked. `Fetch` uses it, and
  so do the pushes of gg_one_commit (`do push`) and gg_one_do_publish.
- `lib/src/base/git_watch.dart` — `GitWatch.run` runs a git network command
  with `start` of `GgProcessDelegate.defaultDelegate`, never in a shell, and
  reads its stderr while it runs. Like every `ggRunProcess` process it is
  **not** tracked by the `GgProcessScope` — a cancelled scope lets it finish.
  `GitWatch.watch(body)` installs a watching delegate for `body`
  (`GgProcessDelegate.runWith`), so every **git** `ggRunProcess` /
  `GgProcessWrapper.run` inside is watched, whatever runner the caller uses.
  Passed through unwatched: other programs (`gh pr create` runs inside
  `GitRetry` too), `ggStartProcess`, output asked for as bytes (encoding
  `null`), and everything while a delegate other than the default one is
  installed (embedders, tests answering commands themselves); an injected
  fake runner never gets there. Output is decoded with the encodings the
  caller passed, like `Process.run`. **`GitRetry.run` watches every attempt**
  (`GitRetry.watch`, `GitRetry.example` uses `GitWatch.example`), so every
  git network command of the family — push, publish, fetch, ls-remote,
  clone — is covered without code at the call sites. A remote can turn
  a request away and keep the connection open (Azure DevOps prints
  »VS403463: The conditional access policy … has failed« and git waits for
  hours); on such a message (`isFatalRemoteMessage`: `vs403463:` — the
  colon keeps the branch names a fetch lists from matching; only the new
  stderr plus a short overlap is searched) the watch ends git and its ssh
  (`taskkill /T` on Windows, `pkill -P` elsewhere, then `kill`; a missing
  tool is tolerated) and returns exit 128 with the stderr — unless git
  ended by itself within 500 ms of the message, then its own exit code
  counts; output arriving later triggers no notice. A command silent for `quietNotice` (30 s) is reported
  to `ggLog`, again after every further 30 s, but keeps running. stdin is
  closed, so a prompt fails instead of waiting; output is read as UTF-8.
  The notice names the folder (`… in <workingDirectory>`); one timer per
  silence (`_QuietNotice`), not one per chunk. The kill tools run through the
  default delegate, never watched or refused by a cancelled scope. The VS403463 check itself lives once, in `SshHostKeys`. Tests fake ssh with
  the test helper `writeFakeSsh` (`core.sshCommand` + `ssh.variant=ssh`);
  the script must wait with the builtin `read`, a forked `sleep` loses its
  parent under MSYS and survives the kill.
- `SshHostKeys.isConditionalAccessFailure` / `setupHint` — VS403463 counts as
  a setup problem; the hint says to sign in to `https://dev.azure.com/<org>`
  (`azureOrganizationOf`: ssh, ssh://, https and legacy
  `https://<org>.visualstudio.com` forms) in the browser.
  `GitRetry` never retries it. `hintScope` tells callers what to show a
  hint once per: the Azure organization for VS403463, else the ssh host.
- `lib/src/base/git_version.dart` — `GitVersion.isAtLeast(major, minor)`
  asks `git --version` once per process and never throws (an unreadable
  answer counts as older than everything). `GitVersion.fixed` / `.unknown`
  are for tests. `Fetch` uses it to decide between the two ways below.
- `lib/src/commands/fetch.dart` — `Fetch.get` takes two options that save
  connections: `mirrorTags` (`--prune --prune-tags --force`: the tags become
  a copy of the remote's — one fetch instead of deleting the local tags and
  fetching them twice) and `refreshDefaultBranch` (`origin/HEAD` names the
  remote's default branch afterwards: with git ≥ 2.48 through
  `-c remote.origin.followRemoteHEAD=always` in the same connection, with an
  older git through `git remote set-head origin --auto` afterwards, retried
  and never failing the fetch). `Fetch.arguments` builds the command line
  for callers that run git through their own process runner.
- `lib/src/base/wait_for_both.dart` — `waitForBoth(a, b)` runs two things
  at the same time and reports a failure only once **both** are through:
  a git process that is still running holds on to its working directory
  (Windows refuses to delete it), which `Future.wait(…, eagerError: true)`
  ignores. `LastChangesHash` and `UnstagedFiles` read with it.
- `lib/src/commands/last_changes_hash.dart` — hashes the unstaged files
  with **one** `git hash-object -- <files>` per command line full
  (`maxCommandLineLength`), not one call per file; a deleted file or a
  folder gets the empty hash without asking git, and a call git refuses
  falls back to file by file. The hash values are unchanged.
- `lib/src/base/ssh_host_keys.dart` — `SshHostKeys` classifies the stderr
  of a failed ssh connection (`isUnknownHost`, `isChangedHostKey` — both
  print »Host key verification failed«, only an unknown host may be
  trusted —, `isKeyRejected`), says what to do next (`setupHint`, per
  host — Azure DevOps takes RSA keys only), reads the host of a remote url as
  known_hosts names it (`hostOf`: `host` or `[host]:port`), and reads the
  key an unknown host presents with `scan`: `git ls-remote` with a
  `GIT_SSH_COMMAND` — the user's own (`GIT_SSH_COMMAND`, `core.sshCommand`,
  else `ssh`) plus options — that accepts the key into an empty known_hosts
  file of its own. So it is the ssh and ssh config git itself uses (Git for
  Windows bundles one; `ssh-keyscan` is often not on the PATH there). The
  temp path goes in as `'UserKnownHostsFile="…"'`: double quotes for ssh,
  which splits the value at spaces, single quotes for sh. `checkFingerprint`
  compares with the fingerprints GitHub and Azure DevOps publish;
  `SshHostKey.fingerprint` is computed in Dart (SHA256 of the key blob,
  like `ssh-keygen -l`). `trust` appends to `~/.ssh/known_hosts`, skipping
  lines already there; the home is found like Git for Windows does (HOME,
  else HOMEDRIVE+HOMEPATH if it exists, else USERPROFILE). A custom
  `UserKnownHostsFile` in `~/.ssh/config` is not followed. `Fetch` appends
  `setupHint` (with the url of `origin`) to its error when
  `isSetupProblem` matches, so every caller of `Fetch` explains ssh
  problems without code of its own.
- `lib/src/commands/upstream_branch.dart` — `UpstreamBranch` answers »no
  upstream« (empty string) not only for a branch without tracking config
  but also for one whose configured upstream ref is gone: the remote branch
  was merged and deleted (auto-completed pull request), then pruned by a
  fetch. `IsPushed` and the pushes of gg_one_commit then push with
  `--set-upstream` instead of dying on a ref that no longer exists.
- `lib/src/commands/` — one command class per file, based on
  `GgGitBase`/`DirCommand`. `ggLog` is constructor-injected everywhere.
- `lib/src/test_helpers/test_helpers.dart` — public helpers that build real
  git repos for tests (`initGit`, `initLocalAndRemoteGit`, …). Exported via
  `lib/gg_git_test_helpers.dart` and consumed by gg_one, gg_publish and
  gg_version. The file is `coverage:ignore-file`. The helpers start as few
  git processes as they can — the processes are what a test run waits for
  (see »Testing Conventions«): `initLocalGit` checks `main` out only in a
  repository that was there before (a new one is on `main` right away);
  `commitFile` asks `git status` only when git refuses the commit — except
  for an amend, which would rewrite the last commit also when nothing
  changed and therefore asks first — and commits with
  `maintenance.auto=false`, so no detached `git maintenance` outlives the
  test and holds on to its folder.
- `lib/src/test_helpers/cached_repos.dart` — cached fixture variants:
  `initCachedRepo` / `initCachedRepoPair` build a fixture once per isolate
  (memoized by a caller-chosen string key) and deliver pure-Dart directory
  copies per call. Pairs rewire `origin` to the copied remote via
  `git remote set-url` (the only git spawn per copy). Template dirs are
  never handed out and never deleted. This file is fully covered — do not
  add `coverage:ignore` markers here.

## Testing Conventions

- 100% code coverage is required (`gg can commit` runs the gg_test gate).
  Exempt lines only with `// coverage:ignore-line` / `-start` / `-end`.
- Each implementation file has a mirrored `_test.dart` under `test/`
  (e.g. `lib/src/test_helpers/cached_repos.dart` ↔
  `test/test_helpers/cached_repos_test.dart`).
- Mock classes live at the bottom of the same file as the class they mock
  (`mocktail`).
- Prefer the cached helpers in new tests when a fixture is rebuilt in every
  `setUp` — they reduce git process spawns by an order of magnitude.
  **The git processes are what this suite takes its time for**: measured on
  22 processors under Windows, a machine starts about 25 of them per second,
  whether three or eleven test files run at once (111 s and 90 s for the
  whole suite). The suite started 2830 git processes; with the lighter
  helpers and the standard repositories taken from the templates
  (`initCachedGit`, `initCachedLocalAndRemoteGit`) it starts 1566, and the
  run with every process traced went from 107 s to 71 s. So a new test
  takes `initCachedGit(d)` instead of `initGit(d)` on a fresh folder, and
  `initCachedLocalAndRemoteGit()` in a `setUp`. `initGit` stays where the
  folder is not empty, where a repository is initialized a second time, and
  for the tests of the helpers themselves.
- Existing helpers in `test_helpers.dart` must stay backwards compatible —
  four packages depend on them.

<!-- helix:claude_md:start -->
<!-- helix:claude_md:end -->
