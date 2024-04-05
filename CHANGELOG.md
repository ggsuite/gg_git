# Change Log

## [2.5.4] - 2024-04-05

### Removed

- Outputs to fix pipeline errors

## [2.5.3] - 2024-04-05

### Added

- Add output to fix github hash error

## [2.5.2] - 2024-04-05

### Fixed

- Ammending with ammendWhenNotPushed will not overwrite the previous commit message

## 2.5.1 - 2024-04-04

### Added

- option `--ammend-when-not-pushed` to `Commit`
- `deleteFileAndCommit`
- `ModifiedFiles:` Allow to ignore files that were deleted
- `addAndCommitPubspecFile`
- `pushLocalChanges`
- `initLocalAndRemoteGit`
- `revertLocalChanges`
- Test helpers
- `IsPushed.get` has an option `ignoreUnCommittedChanges` which allows to ignore uncommitted changes.
- `HasRemote` returns true when git has a remote repo
- `HeadMessage`: Allow to return head message also when not everything is committed.
- `modified-files`

[2.5.4]: https://github.com/inlavigo/gg_git/compare/2.5.3...2.5.4
[2.5.3]: https://github.com/inlavigo/gg_git/compare/2.5.2...2.5.3
[2.5.2]: https://github.com/inlavigo/gg_git/compare/2.5.1...2.5.2
