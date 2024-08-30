# Changelog

## [2.5.14] - 2024-08-30

### Changed

- Make unit tests work on windows

## [2.5.13] - 2024-08-20

### Fixed

- Fix an error - Hash calculation with binary files did not work

## [2.5.12] - 2024-04-13

### Removed

- dependency pana

## [2.5.11] - 2024-04-12

### Removed

- dependency to gg\_install\_gg, remove ./check script

## [2.5.10] - 2024-04-11

### Changed

- Upgrade dependencies

## [2.5.9] - 2024-04-11

### Changed

- Improve mocks

## [2.5.8] - 2024-04-09

### Removed

- 'Pipline: Disable cache'

## [2.5.7] - 2024-04-09

### Fixed

- TestHelpers: CHANGELOG.md version did not have the civer format

## [2.5.6] - 2024-04-09

### Fixed

- TestHelpers: addAndCommitVersions: appendToPubspec: can only append one time

## [2.5.5] - 2024-04-08

### Added

- TestHelpers: addAndCommitVersions: Allow to append additional content to pubspec.yaml

### Changed

- Kidney: Auto check all repos
- Rework changelog
- 'Github Actions Pipeline'
- 'Github Actions Pipeline: Add SDK file containing flutter into .github/workflows to make github installing flutter and not dart SDK'

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

[2.5.14]: https://github.com/inlavigo/gg_git/compare/2.5.13...2.5.14
[2.5.13]: https://github.com/inlavigo/gg_git/compare/2.5.12...2.5.13
[2.5.12]: https://github.com/inlavigo/gg_git/compare/2.5.11...2.5.12
[2.5.11]: https://github.com/inlavigo/gg_git/compare/2.5.10...2.5.11
[2.5.10]: https://github.com/inlavigo/gg_git/compare/2.5.9...2.5.10
[2.5.9]: https://github.com/inlavigo/gg_git/compare/2.5.8...2.5.9
[2.5.8]: https://github.com/inlavigo/gg_git/compare/2.5.7...2.5.8
[2.5.7]: https://github.com/inlavigo/gg_git/compare/2.5.6...2.5.7
[2.5.6]: https://github.com/inlavigo/gg_git/compare/2.5.5...2.5.6
[2.5.5]: https://github.com/inlavigo/gg_git/compare/2.5.4...2.5.5
[2.5.4]: https://github.com/inlavigo/gg_git/compare/2.5.3...2.5.4
[2.5.3]: https://github.com/inlavigo/gg_git/compare/2.5.2...2.5.3
[2.5.2]: https://github.com/inlavigo/gg_git/compare/2.5.1...2.5.2
