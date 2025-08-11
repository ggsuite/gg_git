# Changelog

## [3.0.1] - 2025-08-11

### Changed

- initGit creates .gitattributes file

## [3.0.0] - 2025-08-11

### Changed

- BREAKING CHANGE V.3.0.0: EOL LF or AUTO IS ENFORCED

## [2.5.22] - 2025-06-07

### Changed

- Replace line endings with linux line endings

## [2.5.21] - 2025-06-07

### Changed

- Replace not platform save hash algorithm by an own one

## [2.5.20] - 2025-06-05

### Changed

- Create a new version

## [2.5.19] - 2025-06-05

### Fixed

- Fix unit test errors

## [2.5.18] - 2025-06-05

### Changed

- Update to dart 3.8.0

## [2.5.17] - 2025-06-05

### Added

- Added exception for UpstreamBranch.get

## [2.5.16] - 2024-10-03

### Added

- Add createBranch and branchName to test\_helpers.dart
- Add command UpstreamBranch

### Changed

- Improved error output when a sub command is not listed in commands
- When commit with ammendWhenNotPushed = true is called and no upstream branch is set, changes will be ammended

## [2.5.15] - 2024-08-30

### Changed

- LastChangesHash will be the same independent of carriage return resp. line breaks

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

[3.0.1]: https://github.com/inlavigo/gg_git/compare/3.0.0...3.0.1
[3.0.0]: https://github.com/inlavigo/gg_git/compare/2.5.22...3.0.0
[2.5.22]: https://github.com/inlavigo/gg_git/compare/2.5.21...2.5.22
[2.5.21]: https://github.com/inlavigo/gg_git/compare/2.5.20...2.5.21
[2.5.20]: https://github.com/inlavigo/gg_git/compare/2.5.19...2.5.20
[2.5.19]: https://github.com/inlavigo/gg_git/compare/2.5.18...2.5.19
[2.5.18]: https://github.com/inlavigo/gg_git/compare/2.5.17...2.5.18
[2.5.17]: https://github.com/inlavigo/gg_git/compare/2.5.16...2.5.17
[2.5.16]: https://github.com/inlavigo/gg_git/compare/2.5.15...2.5.16
[2.5.15]: https://github.com/inlavigo/gg_git/compare/2.5.14...2.5.15
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
