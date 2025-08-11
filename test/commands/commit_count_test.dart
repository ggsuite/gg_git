// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_git/src/commands/commit_count.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late CommitCount commitCount;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    commitCount = CommitCount(ggLog: messages.add);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('CommitCount', () {
    group('get(ggLog, directory)', () {
      test(
        'should return the number of commits in the current branch',
        () async {
          await initGit(d, isEolLfEnabled: false);
          var count = await commitCount.get(ggLog: messages.add, directory: d);
          expect(count, 0);

          await addAndCommitSampleFile(d);
          count = await commitCount.get(ggLog: messages.add, directory: d);
          expect(count, 1);
        },
      );

      group('should throw', () {
        test('when git rev-list --all --count fails', () async {
          await initGit(d);

          // Make git rev-list fail
          final processWrapper = MockGgProcessWrapper();
          when(
            () => processWrapper.run('git', [
              'rev-list',
              '--all',
              '--count',
            ], workingDirectory: d.path),
          ).thenAnswer((_) async => ProcessResult(1, 1, '', 'Some error'));

          // Create the command
          final commitCount = CommitCount(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );

          // Run the command
          late String exception;

          try {
            await commitCount.get(ggLog: messages.add, directory: d);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            contains(
              'Could not run "git rev-list --all --count" '
              'in "test": Some error',
            ),
          );
        });
      });
    });

    group('exec(directory, ggLog)', () {
      test(
        'should print the number of commits in the current branch',
        () async {
          await initGit(d, isEolLfEnabled: false);
          await addAndCommitSampleFile(d);

          await commitCount.exec(directory: d, ggLog: messages.add);
          expect(messages, ['1']);
        },
      );

      test('should allow to use the command via command line', () async {
        await initGit(d, isEolLfEnabled: false);
        await addAndCommitSampleFile(d);

        final runner = CommandRunner<void>('test', 'test');
        runner.addCommand(commitCount);

        await runner.run(['commit-count', '-i', d.path]);
        expect(messages, ['1']);
      });
    });
  });
}
