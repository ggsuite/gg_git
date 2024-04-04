# Change Log

## 2.5.1

- Add option `--ammend-when-not-pushed` to `Commit`

## 2.4.1

- Fix: `LastChangesHash` was broken when files were deleted

## 2.4.0

- Add `deleteFileAndCommit`
- `ModifiedFiles:` Allow to ignore files that were deleted
- Fix some small errors

## 2.3.0

- Add `addAndCommitPubspecFile`

## 2.2.0

- Add `pushLocalChanges`

## 2.1.0

- Add `initLocalAndRemoteGit`

## 2.0.1

- Add `revertLocalChanges` test helper

## 2.0.0

- Breaking changes: Renamed various test helpers

## 1.8.4

- Fix a small bug in test helpers

## 1.8.3

- `IsPushed.get` has an option `ignoreUnCommittedChanges` which allows to ignore uncommitted changes.

## 1.8.2

- `HeadMessage`: Allow to return head message also when not everything is committed.

## 1.8.1

- ModifiedFiles: Skip commits that only contain ignored files

## 1.8.0

- Add `HasRemote` command

## 1.7.0

- Add `ammend` option for `Commit`

## 1.6.2

- Add `ignoreFiles` option to several functions

## 1.6.1

- Add `--force` option to `modified-files` & `head hash`
- Add `last-changes-hash`

## 1.5.0

- Add `gg_git head message|hash`

## 1.4.1

- Add `commit` command

## 1.3.1

- Add `modified-files` command

## 1.2.2

- Add `head-message` command
- head-hash command: Add Option --offset -o to get predecessor of the head hash

## 1.0.19

- Breaking change: Made all test helpers async

## 1.0.18

- Replace gg_check by gg
- Turn addFileWithoutCommitting into Future

## 1.0.17

- Update GgConsoleColors

## 1.0.16

- Add GgLog

## 1.0.15

- Add `head-hash` returning the hash of the current head revision

## 1.0.13

- Add mocks

## 1.0.12

- Rework `DirCommand`

## 1.0.11

- Turn static methods in class methods to allow mocking
- Various renamings

## 1.0.7

- Make pipeline working

## 1.0.6

- Colorful command line outputs
- Remove double `Everything is pushed.` message

## 1.0.2

- Rename `is-committed` to `committed`
- Rename `is-pushed` to `pushed`

## 1.0.1

- Update dependencies
- Make test_helpers public

## 1.0.0

- Initial version.
