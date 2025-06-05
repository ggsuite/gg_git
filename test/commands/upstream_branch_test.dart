// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory dLocal;
  late Directory dRemote;

  final messages = <String>[];
  late CommandRunner<void> runner;
  late UpstreamBranch upstreamBranch;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    upstreamBranch = UpstreamBranch(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(upstreamBranch);
  }

  // ...........................................................................
  setUp(() async {
    dLocal = await initTestDir();
    dRemote = await initTestDir();
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  tearDown(() {
    dLocal.deleteSync(recursive: true);
    dRemote.deleteSync(recursive: true);
  });

  group('UpstreamBranch', () {
    // #########################################################################
    group('get()', () {
      test('should throw if "git rev-parse" fails', () async {
        await initGit(dLocal);
        final failingProcessWrapper = MockGgProcessWrapper();

        initCommand(processWrapper: failingProcessWrapper);

        when(
          () => failingProcessWrapper.run('git', [
            'rev-parse',
            '--abbrev-ref',
            '--symbolic-full-name',
            '@{u}',
          ], workingDirectory: dLocal.path),
        ).thenAnswer(
          (_) async => ProcessResult(
            1,
            1,
            'Something went wrong',
            'Something went wrong',
          ),
        );

        late String exception;

        try {
          await upstreamBranch.get(directory: dLocal, ggLog: messages.add);
        } catch (e) {
          exception = e.toString();
        }

        expect(
          exception,
          'Exception: Could not run "git rev-parse" in "test": '
          'Something went wrong.',
        );
      });

      // .......................................................................
      group('should return', () {
        group('an empty string', () {
          test('when the repo has no remote', () async {
            await initGit(dLocal);
            initCommand();

            final result = await upstreamBranch.get(
              directory: dLocal,
              ggLog: messages.add,
            );

            expect(result, isEmpty);
          });

          test('when the repo has a remote '
              'but the current branch has no upstream', () async {
            await initGit(dLocal);

            initCommand();
            await initRemoteGit(dRemote);
            await addRemoteToLocal(local: dLocal, remote: dRemote);

            // The main branch has an upstream
            final result = await upstreamBranch.get(
              directory: dLocal,
              ggLog: messages.add,
            );

            expect(result, 'origin/main');

            // Create a local branch
            await createBranch(dLocal, 'feature');

            // No upstream for the feature branch
            final result2 = await upstreamBranch.get(
              directory: dLocal,
              ggLog: messages.add,
            );

            expect(result2, isEmpty);
          });
        });

        // .....................................................................
        group('the remote branch name', () {
          test(
            'when the repo has a remote and the branch has an upstream',
            () async {
              await initGit(dLocal);

              initCommand();
              await initRemoteGit(dRemote);
              await addRemoteToLocal(local: dLocal, remote: dRemote);

              final result = await upstreamBranch.get(
                directory: dLocal,
                ggLog: messages.add,
              );

              expect(result, 'origin/main');
            },
          );
        });
      });
    });

    group('exec(directory, ggLog)', () {
      group('should print nothing', () {
        test('when repo has no remote', () async {
          await initGit(dLocal);
          initCommand();
          await runner.run(['upstream-branch', '-i', dLocal.path]);
          expect(messages, isEmpty);
        });
      });

      group('should print the remote branch when available', () {
        test('when repo has a remote', () async {
          await initGit(dLocal);
          await addAndCommitSampleFile(dLocal);

          initCommand();
          await initRemoteGit(dRemote);
          await addRemoteToLocal(local: dLocal, remote: dRemote);

          await runner.run(['upstream-branch', '-i', dLocal.path]);

          expect(messages[0], 'origin/main');
        });
      });
    });
  });
}
