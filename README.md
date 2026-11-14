# gg_git

A collection of git helper scripts for repository checks and other utilities.

## Fetch

`Fetch.get(mirrorTags: true)` makes the tags of a checkout a copy of the
remote's, in the connection of the fetch. `refreshDefaultBranch: true` lets
`origin/HEAD` name the default branch of the remote afterwards — in the
same connection with git 2.48 or newer (`GitVersion.isAtLeast`), with one
more call for an older git.

## Retrying network commands

`GitRetry` reruns a git network command that failed because the connection
was dropped or throttled: four attempts, 5 s, 15 s and 45 s apart. A remote
that answers with a rate limit (HTTP 429, »rate limit«) is asked again as
well, after a minute, doubled with every retry. A rejected push, missing
credentials or an unknown repository is never retried.

## SSH host keys

`SshHostKeys` helps when git cannot connect to an ssh remote: it tells an
unknown host (`isUnknownHost`) from a changed host key (`isChangedHostKey`)
and a refused user key (`isKeyRejected`), reads the key an unknown host
presents without trusting it (`scan`), tells the developer what to do
next (`setupHint`), compares its fingerprint with the
fingerprints GitHub and Azure DevOps publish (`checkFingerprint`) and adds
it to `~/.ssh/known_hosts` (`trust`).

```dart
final hostKeys = SshHostKeys();
final host = SshHostKeys.hostOf(url)!;
for (final key in await hostKeys.scan(url)) {
  print('${key.typeName} ${key.fingerprint} '
      '${SshHostKeys.checkFingerprint(host, key)}');
}
```

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
