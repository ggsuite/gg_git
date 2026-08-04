// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  final createdDirs = <Directory>[];

  // ...........................................................................
  Future<Directory> tempDir() async {
    final d = await Directory.systemTemp.createTemp('cached_repos_test_');
    createdDirs.add(d);
    return d;
  }

  // ...........................................................................
  Future<int> commitCount(Directory repo) async {
    final result = await Process.run('git', [
      'rev-list',
      '--count',
      'main',
    ], workingDirectory: repo.path);
    return int.parse((result.stdout as String).trim());
  }

  // ...........................................................................
  tearDown(() async {
    for (final d in createdDirs) {
      if (await d.exists()) {
        await d.delete(recursive: true);
      }
    }
    createdDirs.clear();
  });

  group('CachedRepos', () {
    group('initCachedRepo(target, key, build)', () {
      test('builds the template only once and delivers working copies', () //
      async {
        var buildCount = 0;
        Future<void> build(Directory repo) async {
          buildCount++;
          await initGit(repo, isEolLfEnabled: false);
          await addAndCommitSampleFile(repo);
        }

        final d0 = await tempDir();
        await initCachedRepo(d0, key: 'build_once', build: build);
        final d1 = await tempDir();
        await initCachedRepo(d1, key: 'build_once', build: build);

        expect(buildCount, 1);

        // The copy is a complete git repo incl. the .git folder
        expect(File(join(d1.path, sampleFileName)).existsSync(), isTrue);
        expect(
          File(join(d1.path, '.git', 'HEAD')).readAsStringSync(),
          contains('refs/heads/main'),
        );
        expect(await branchName(d1), 'main');

        // The copied index reports a clean state
        expect(await modifiedFiles(d1), isEmpty);
      });

      test('copies are independent of each other', () async {
        Future<void> build(Directory repo) async {
          await initGit(repo, isEolLfEnabled: false);
          await addAndCommitSampleFile(repo);
        }

        final d0 = await tempDir();
        await initCachedRepo(d0, key: 'independent', build: build);
        final d1 = await tempDir();
        await initCachedRepo(d1, key: 'independent', build: build);

        // Mutating copy 0 does not affect copy 1
        await addAndCommitSampleFile(d0, fileName: 'extra.txt');
        expect(File(join(d1.path, 'extra.txt')).existsSync(), isFalse);
        expect(await commitCount(d0), 2);
        expect(await commitCount(d1), 1);
      });

      test('different keys create different templates', () async {
        var buildCountA = 0;
        var buildCountB = 0;

        final d0 = await tempDir();
        await initCachedRepo(
          d0,
          key: 'key_a',
          build: (repo) async {
            buildCountA++;
            await File(join(repo.path, 'a.txt')).writeAsString('a');
          },
        );

        final d1 = await tempDir();
        await initCachedRepo(
          d1,
          key: 'key_b',
          build: (repo) async {
            buildCountB++;
            await File(join(repo.path, 'b.txt')).writeAsString('b');
          },
        );

        expect(buildCountA, 1);
        expect(buildCountB, 1);
        expect(File(join(d0.path, 'a.txt')).existsSync(), isTrue);
        expect(File(join(d1.path, 'b.txt')).existsSync(), isTrue);
        expect(File(join(d1.path, 'a.txt')).existsSync(), isFalse);
      });

      test('throws when the target dir is not empty', () async {
        final d = await tempDir();
        await File(join(d.path, 'existing.txt')).writeAsString('x');

        await expectLater(
          initCachedRepo(d, key: 'non_empty_target', build: (repo) async {}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'message',
              contains('must be empty'),
            ),
          ),
        );
      });

      test('creates the target dir when it does not exist', () async {
        final parent = await tempDir();
        final target = Directory(join(parent.path, 'not', 'existing'));

        await initCachedRepo(
          target,
          key: 'missing_target',
          build: (repo) async {
            await File(join(repo.path, 'a.txt')).writeAsString('a');
          },
        );

        expect(File(join(target.path, 'a.txt')).existsSync(), isTrue);
      });

      test('does not cache failed builds', () async {
        var buildCount = 0;
        Future<void> build(Directory repo) async {
          buildCount++;
          if (buildCount == 1) {
            throw Exception('Build failed');
          }
          await File(join(repo.path, 'a.txt')).writeAsString('a');
        }

        final d0 = await tempDir();
        await expectLater(
          initCachedRepo(d0, key: 'fail_once', build: build),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Build failed'),
            ),
          ),
        );

        // The second call retries the build and succeeds
        await initCachedRepo(d0, key: 'fail_once', build: build);
        expect(buildCount, 2);
        expect(File(join(d0.path, 'a.txt')).existsSync(), isTrue);
      });

      test('sanitizes weird keys', () async {
        final d = await tempDir();
        await initCachedRepo(
          d,
          key: 'weird/key: 1',
          build: (repo) async {
            await File(join(repo.path, 'a.txt')).writeAsString('a');
          },
        );
        expect(File(join(d.path, 'a.txt')).existsSync(), isTrue);
      });
    });

    group('initCachedRepoPair(key, build)', () {
      test('builds once, rewires origin and isolates the copies', () async {
        var buildCount = 0;
        Future<void> build(Directory local, Directory remote) async {
          buildCount++;
          await initLocalGit(local);
          await initRemoteGit(remote);
          await addRemoteToLocal(local: local, remote: remote);
        }

        final (l0, r0) = await initCachedRepoPair(key: 'pair', build: build);
        final (l1, r1) = await initCachedRepoPair(key: 'pair', build: build);
        createdDirs.addAll([l0, r0, l1, r1]);

        expect(buildCount, 1);

        // Each copied local points to its own copied remote
        for (final (l, r) in [(l0, r0), (l1, r1)]) {
          final url = await Process.run('git', [
            'remote',
            'get-url',
            'origin',
          ], workingDirectory: l.path);
          expect((url.stdout as String).trim(), r.path);
          expect(await upstreamBranchName(l), 'origin/main');
        }

        // A push from copy 0 arrives in remote 0 but not in remote 1
        await addAndCommitSampleFile(l0);
        await pushLocalChanges(l0);
        expect(await commitCount(r0), 2);
        expect(await commitCount(r1), 1);
      });

      test('skips rewiring when the local repo has no origin', () async {
        final (l, r) = await initCachedRepoPair(
          key: 'pair_without_origin',
          build: (local, remote) async {
            await initLocalGit(local);
            await initRemoteGit(remote);
          },
        );
        createdDirs.addAll([l, r]);

        final remotes = await Process.run('git', [
          'remote',
        ], workingDirectory: l.path);
        expect((remotes.stdout as String).trim(), isEmpty);
      });

      test('also copies pairs that are no git repos', () async {
        final (l, r) = await initCachedRepoPair(
          key: 'pair_without_git',
          build: (local, remote) async {
            await File(join(local.path, 'a.txt')).writeAsString('a');
            await File(join(remote.path, 'b.txt')).writeAsString('b');
          },
        );
        createdDirs.addAll([l, r]);

        expect(File(join(l.path, 'a.txt')).existsSync(), isTrue);
        expect(File(join(r.path, 'b.txt')).existsSync(), isTrue);
        expect(Directory(join(l.path, '.git')).existsSync(), isFalse);
      });

      test('throws when origin cannot be rewired', () async {
        await expectLater(
          initCachedRepoPair(
            key: 'broken_config',
            build: (local, remote) async {
              // A .git folder that only contains a config file is no valid
              // git repository - »git remote set-url« will fail on the copy.
              final config = File(join(local.path, '.git', 'config'));
              await config.create(recursive: true);
              await config.writeAsString('[remote "origin"]\n');
            },
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Could not set remote url'),
            ),
          ),
        );
      });
    });

    group('initCachedGit(testDir)', () {
      test('mirrors initGit for both isEolLfEnabled values', () async {
        for (final eol in [true, false]) {
          final d0 = await tempDir();
          await initCachedGit(d0, isEolLfEnabled: eol);
          expect(await branchName(d0), 'main');
          expect(await isEolLfEnabled(d0), eol);

          // The second call returns a copy without rebuilding
          final d1 = await tempDir();
          await initCachedGit(d1, isEolLfEnabled: eol);
          expect(await isEolLfEnabled(d1), eol);
        }
      });
    });

    group('initCachedLocalAndRemoteGit()', () {
      test('mirrors initLocalAndRemoteGit', () async {
        final (l, r) = await initCachedLocalAndRemoteGit();
        createdDirs.addAll([l, r]);

        expect(await branchName(l), 'main');
        expect(await upstreamBranchName(l), 'origin/main');
        expect(File(join(l.path, 'init')).existsSync(), isTrue);

        // Pushing to the copied remote works
        await addAndCommitSampleFile(l);
        await pushLocalChanges(l);
        expect(await commitCount(r), 2);
      });
    });

    group('pushLocalChangesUpstream(d, branch)', () {
      test('pushes local changes and creates an upstream branch', () async {
        final (l, r) = await initCachedLocalAndRemoteGit();
        createdDirs.addAll([l, r]);

        await createBranch(l, 'feat_x');
        await addAndCommitSampleFile(l);
        expect(await upstreamBranchName(l), isEmpty);

        await pushLocalChangesUpstream(l, 'feat_x');
        expect(await upstreamBranchName(l), 'origin/feat_x');
      });

      test('throws when the directory is no git repo', () async {
        final d = await tempDir();
        await expectLater(
          pushLocalChangesUpstream(d, 'main'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Could not add local changes'),
            ),
          ),
        );
      });

      test('throws when the repo has no remote', () async {
        final d = await tempDir();
        await initGit(d, isEolLfEnabled: false);
        await addAndCommitSampleFile(d);

        await expectLater(
          pushLocalChangesUpstream(d, 'main'),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Could not push local changes with upstream'),
            ),
          ),
        );
      });
    });
  });
}
