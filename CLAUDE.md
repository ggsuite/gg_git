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

- `lib/src/commands/` — one command class per file, based on
  `GgGitBase`/`DirCommand`. `ggLog` is constructor-injected everywhere.
- `lib/src/test_helpers/test_helpers.dart` — public helpers that build real
  git repos for tests (`initGit`, `initLocalAndRemoteGit`, …). Exported via
  `lib/gg_git_test_helpers.dart` and consumed by gg_one, gg_publish and
  gg_version. The file is `coverage:ignore-file`.
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
- Existing helpers in `test_helpers.dart` must stay backwards compatible —
  four packages depend on them.
