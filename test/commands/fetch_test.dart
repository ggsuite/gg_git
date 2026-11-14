// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  final messages = <String>[];
  late MockGgProcessWrapper processWrapper;
  late Fetch fetch;

  setUp(() async {
    d = await initTestDir();
    messages.clear();
    processWrapper = MockGgProcessWrapper();
    fetch = Fetch(ggLog: messages.add, processWrapper: processWrapper);
  });

  tearDown(() => d.deleteSync(recursive: true));

  group('Fetch', () {
    test('runs "git fetch" on success', () async {
      when(() => processWrapper.run('git', ['fetch'], workingDirectory: d.path))
          .thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      await fetch.get(directory: d, ggLog: messages.add);

      verify(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).called(1);
    });

    test('throws when fetch fails', () async {
      when(() => processWrapper.run('git', ['fetch'], workingDirectory: d.path))
          .thenAnswer((_) async => ProcessResult(1, 1, '', 'offline'));

      expect(
        () => fetch.get(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not fetch in'),
          ),
        ),
      );
    });

    test('exec delegates to get', () async {
      when(() => processWrapper.run('git', ['fetch'], workingDirectory: d.path))
          .thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      await fetch.exec(directory: d, ggLog: messages.add);

      verify(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).called(1);
    });

    test('retries a fetch the remote dropped and then succeeds', () async {
      fetch = Fetch(
        ggLog: messages.add,
        processWrapper: processWrapper,
        gitRetry: GitRetry.example,
      );
      var calls = 0;
      when(() => processWrapper.run('git', ['fetch'], workingDirectory: d.path))
          .thenAnswer((_) async {
            final dropped = calls++ == 0;
            return ProcessResult(
              1,
              dropped ? 1 : 0,
              '',
              dropped ? 'Connection to github.com closed by remote host.' : '',
            );
          });

      await fetch.get(directory: d, ggLog: messages.add);

      verify(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).called(2);
      expect(messages.single, contains('git fetch failed with a transient'));
    });

    test('says what to do when ssh does not know the host', () async {
      when(() => processWrapper.run('git', ['fetch'], workingDirectory: d.path))
          .thenAnswer(
            (_) async =>
                ProcessResult(1, 128, '', 'Host key verification failed.'),
          );
      when(
        () => processWrapper.run('git', [
          'remote',
          'get-url',
          'origin',
        ], workingDirectory: d.path),
      ).thenAnswer(
        (_) async => ProcessResult(1, 0, 'git@github.com:org/repo.git\n', ''),
      );

      await expectLater(
        fetch.get(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('Could not fetch in'),
              contains(
                '\nSSH does not know github.com yet. Run "git ls-remote '
                'git@github.com:org/repo.git" once',
              ),
            ),
          ),
        ),
      );
    });

    test('reports stdout when fetch fails with empty stderr', () async {
      when(() => processWrapper.run('git', ['fetch'], workingDirectory: d.path))
          .thenAnswer((_) async => ProcessResult(1, 1, 'fatal: offline', ''));

      expect(
        () => fetch.get(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('fatal: offline'),
          ),
        ),
      );
    });

    group('with mirrorTags', () {
      test('prunes and forces the tags in the same fetch', () async {
        const args = ['fetch', '--prune', '--prune-tags', '--force'];
        when(() => processWrapper.run('git', args, workingDirectory: d.path))
            .thenAnswer((_) async => ProcessResult(1, 0, '', ''));

        await fetch.get(directory: d, ggLog: messages.add, mirrorTags: true);

        verify(() => processWrapper.run('git', args, workingDirectory: d.path))
            .called(1);
        verifyNoMoreInteractions(processWrapper);
      });

      test('makes the local tags a copy of the remote tags', () async {
        final (local, remote) = await initLocalAndRemoteGit();
        addTearDown(() {
          local.deleteSync(recursive: true);
          remote.deleteSync(recursive: true);
        });
        await addAndCommitSampleFile(local);
        await _git(local, ['push', '-u', 'origin', 'HEAD']);
        await _git(local, ['tag', 'kept']);
        await _git(local, ['tag', 'moved']);
        await _git(local, ['push', 'origin', 'kept', 'moved']);
        final pushed = await _git(local, ['rev-parse', 'moved']);

        // A tag only the checkout has, and one it moved away.
        await updateAndCommitSampleFile(local);
        await _git(local, ['tag', 'local-only']);
        await _git(local, ['tag', '--force', 'moved']);

        await Fetch(ggLog: messages.add)
            .get(directory: local, ggLog: messages.add, mirrorTags: true);

        expect(await _git(local, ['tag', '--list']), 'kept\nmoved');
        expect(await _git(local, ['rev-parse', 'moved']), pushed);
      });
    });

    group('with refreshDefaultBranch', () {
      const setHead = ['remote', 'set-head', 'origin', '--auto'];
      const followingFetch = [
        '-c',
        'remote.origin.followRemoteHEAD=always',
        'fetch',
      ];

      Fetch fetchWith(GitVersion gitVersion) => Fetch(
        ggLog: messages.add,
        processWrapper: processWrapper,
        gitRetry: GitRetry.example,
        gitVersion: gitVersion,
      );

      void answer(List<String> args, ProcessResult result) =>
          when(() => processWrapper.run('git', args, workingDirectory: d.path))
              .thenAnswer((_) async => result);

      test('lets a git that can do it update origin/HEAD while it '
          'fetches', () async {
        answer(followingFetch, ProcessResult(1, 0, '', ''));

        await fetchWith(const GitVersion.fixed(2, 48))
            .get(directory: d, ggLog: messages.add, refreshDefaultBranch: true);

        verify(
          () => processWrapper.run(
            'git',
            followingFetch,
            workingDirectory: d.path,
          ),
        ).called(1);
        verifyNoMoreInteractions(processWrapper);
      });

      test('combines with mirrorTags in one fetch', () async {
        const args = [...followingFetch, '--prune', '--prune-tags', '--force'];
        answer(args, ProcessResult(1, 0, '', ''));

        await fetchWith(const GitVersion.fixed(3, 0)).get(
          directory: d,
          ggLog: messages.add,
          refreshDefaultBranch: true,
          mirrorTags: true,
        );

        verify(() => processWrapper.run('git', args, workingDirectory: d.path))
            .called(1);
        verifyNoMoreInteractions(processWrapper);
      });

      test('asks an older git with set-head after the fetch', () async {
        answer(['fetch'], ProcessResult(1, 0, '', ''));
        answer(setHead, ProcessResult(1, 0, '', ''));

        await fetchWith(const GitVersion.fixed(2, 47))
            .get(directory: d, ggLog: messages.add, refreshDefaultBranch: true);

        verifyInOrder([
          () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
          () => processWrapper.run('git', setHead, workingDirectory: d.path),
        ]);
      });

      test('retries a set-head the remote dropped', () async {
        answer(['fetch'], ProcessResult(1, 0, '', ''));
        var calls = 0;
        when(
          () => processWrapper.run('git', setHead, workingDirectory: d.path),
        ).thenAnswer(
          (_) async => calls++ == 0
              ? ProcessResult(1, 128, '', 'Connection closed by remote host.')
              : ProcessResult(1, 0, '', ''),
        );

        await fetchWith(const GitVersion.unknown())
            .get(directory: d, ggLog: messages.add, refreshDefaultBranch: true);

        expect(calls, 2);
        expect(
          messages.single,
          contains('git remote set-head origin --auto failed with a transient'),
        );
      });

      test('does not fail when set-head fails', () async {
        answer(['fetch'], ProcessResult(1, 0, '', ''));
        answer(setHead, ProcessResult(1, 128, '', 'fatal: offline'));

        await fetchWith(const GitVersion.unknown())
            .get(directory: d, ggLog: messages.add, refreshDefaultBranch: true);
      });

      test('does not ask for the default branch when the fetch '
          'failed', () async {
        answer(['fetch'], ProcessResult(1, 1, '', 'offline'));

        await expectLater(
          fetchWith(
            const GitVersion.unknown(),
          ).get(directory: d, ggLog: messages.add, refreshDefaultBranch: true),
          throwsException,
        );
        verifyNever(
          () => processWrapper.run('git', setHead, workingDirectory: d.path),
        );
      });

      test('follows a default branch that was renamed on the remote', () async {
        final (local, remote) = await initLocalAndRemoteGit();
        addTearDown(() {
          local.deleteSync(recursive: true);
          remote.deleteSync(recursive: true);
        });
        await addAndCommitSampleFile(local);
        await _git(local, ['push', '-u', 'origin', 'HEAD']);
        await _git(local, ['remote', 'set-head', 'origin', '--auto']);
        final before = await _git(local, [
          'symbolic-ref',
          'refs/remotes/origin/HEAD',
        ]);

        // The remote gets a new default branch.
        await _git(local, ['push', 'origin', 'HEAD:develop']);
        await _git(remote, ['symbolic-ref', 'HEAD', 'refs/heads/develop']);

        await Fetch(ggLog: messages.add).get(
          directory: local,
          ggLog: messages.add,
          refreshDefaultBranch: true,
        );

        expect(before, isNot('refs/remotes/origin/develop'));
        expect(
          await _git(local, ['symbolic-ref', 'refs/remotes/origin/HEAD']),
          'refs/remotes/origin/develop',
        );
      });
    });

    test('arguments() builds the command line of each option', () {
      expect(Fetch.arguments(), ['fetch']);
      expect(Fetch.arguments(mirrorTags: true), [
        'fetch',
        ...Fetch.mirrorTagsOptions,
      ]);
      expect(Fetch.arguments(followRemoteHead: true), [
        ...Fetch.followRemoteHeadConfig,
        'fetch',
      ]);
    });
  });
}

/// Runs git with [args] in [directory] and returns its trimmed output.
Future<String> _git(Directory directory, List<String> args) async {
  final result = await Process.run(
    'git',
    args,
    workingDirectory: directory.path,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return '${result.stdout}'.trim();
}
