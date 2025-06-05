// @license
// Copyright (c) 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
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
  late LocalBranch localBranch;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    localBranch = LocalBranch(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(localBranch);
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

  group('LocalBranch', () {
    // #########################################################################
    group('get()', () {
      test('should throw if "git branch --show-current" fails', () async {
        await initGit(dLocal);
        final failingProcessWrapper = MockGgProcessWrapper();

        initCommand(processWrapper: failingProcessWrapper);

        when(
          () => failingProcessWrapper.run('git', [
            'branch',
            '--show-current',
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
          await localBranch.get(directory: dLocal, ggLog: messages.add);
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
        group('the branch name', () {
          test(
            'when the repo has a remote and the branch has an local',
            () async {
              await initGit(dLocal);

              initCommand();
              await initRemoteGit(dRemote);
              await addRemoteToLocal(local: dLocal, remote: dRemote);

              final result = await localBranch.get(
                directory: dLocal,
                ggLog: messages.add,
              );

              expect(result, 'main');
            },
          );
        });
      });
    });

    group('exec(directory, ggLog)', () {
      group('should print the branch when available', () {
        test('when repo has a remote', () async {
          await initGit(dLocal);
          await addAndCommitSampleFile(dLocal);

          initCommand();
          await initRemoteGit(dRemote);
          await addRemoteToLocal(local: dLocal, remote: dRemote);

          await runner.run(['local-branch', '-i', dLocal.path]);

          expect(messages[0], 'main');
        });
      });
    });
  });
}
