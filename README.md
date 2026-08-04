# gg_git

A collection of git helper scripts for repository checks and other utilities.

## Test helpers

`package:gg_git/gg_git_test_helpers.dart` provides helpers that create real
git repositories for tests: `initGit`, `initLocalAndRemoteGit`,
`addAndCommitSampleFile` and friends.

### Cached test repos

Building a repository spawns several git processes. When every test's
`setUp` does this, test suites become slow. The cached variants build a
fixture only **once per test file** and deliver a fresh filesystem copy per
call — no git processes are spawned for a copy:

```dart
setUp(() async {
  d = await Directory.systemTemp.createTemp();
  await initCachedRepo(
    d,
    key: 'my_fixture',
    build: (repo) async {
      await initGit(repo);
      await addAndCommitSampleFile(repo);
    },
  );
});
```

For a local repository wired to a bare remote use `initCachedRepoPair`. It
copies both directories together and rewires `origin` to the copied remote
via `git remote set-url` — the only git process spawned per copy:

```dart
setUp(() async {
  (d, dRemote) = await initCachedRepoPair(
    key: 'my_pair',
    build: (local, remote) async {
      await initLocalGit(local);
      await initRemoteGit(remote);
      await addRemoteToLocal(local: local, remote: remote);
    },
  );
});
```

`initCachedGit` and `initCachedLocalAndRemoteGit` are cached drop-in
variants of `initGit` and `initLocalAndRemoteGit`.

Notes:

- Within one test file a `key` must always map to the same recipe — the
  first builder wins. Keys starting with `gg_git/` are reserved.
- Template directories live in the system temp directory and are kept for
  the lifetime of the test process (similar to the temp directories of
  `initTestDir`). The operating system cleans them up eventually.
- Tests own the copies and should delete them in `tearDown` as usual.
