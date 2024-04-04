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
  late Directory d;
  late Directory dRemote;
  late Commit commit;
  late CommitCount commitCount;
  final messages = <String>[];
  const commitMessage = 'My commit message';

  setUp(() async {
    messages.clear();
    (d, dRemote) = await initLocalAndRemoteGit();
    commit = Commit(ggLog: messages.add);
    commitCount = CommitCount(ggLog: messages.add);
  });

  tearDown(() async {
    await d.delete(recursive: true);
    await dRemote.delete(recursive: true);
  });

  group('Commit', () {
    group('commit(directory, message, doStage, ammend)', () {
      group('should throw', () {
        test('if there is nothing to commit', () async {
          // At the beginning, there is nothing to commit
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: 'Initial commit',
              doStage: false,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Nothing to commit. No uncommmited changes.',
          );
        });

        test('if doStage == false and no staged files exist', () async {
          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Commit the file without staging before
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: false,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(exception, contains('use "git add" to track'));

          // Check the commit
        });

        test('if an error happens while staging', () async {
          // Mock staging fails
          final processWrapper = MockGgProcessWrapper();
          when(
            () => processWrapper.run(
              'git',
              ['add', '.'],
              workingDirectory: d.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(1, 1, '', 'Some staging error'),
          );

          // Create an instance
          commit = Commit(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Stage the file
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: 'Initial commit',
              doStage: true,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Could not stage files: Some staging error',
          );
        });

        test('if an error happens while committing', () async {
          // Mock staging succeeds
          final processWrapper = MockGgProcessWrapper();
          when(
            () => processWrapper.run(
              'git',
              ['add', '.'],
              workingDirectory: d.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(1, 0, '', ''),
          );

          // Mock committing fails
          when(
            () => processWrapper.run(
              'git',
              ['commit', '-m', commitMessage],
              workingDirectory: d.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(1, 1, '', 'My commit error.'),
          );

          // Create an instance
          commit = Commit(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Stage the file
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: true,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Could not commit files: My commit error.',
          );
        });

        test('if ammand and ammendWhenNotPushed is true at the same time',
            () async {
          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Commit the file
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: true,
              ammend: true,
              ammendWhenNotPushed: true,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: You cannot use --ammend and --ammend-when-not-pushed '
            'at the same time.',
          );
        });
      });

      group('should commit files', () {
        test('with doStage = true', () async {
          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Commit the file
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ggLog: messages.add,
          );

          // Check the commit
          final result = Process.runSync(
            'git',
            ['log', '-1', '--pretty=%B'],
            workingDirectory: d.path,
          );

          expect(result.stdout.trim(), commitMessage);
        });

        test('with doStage = false', () async {
          // Let's modify two files
          await addFileWithoutCommitting(d, fileName: 'file1.txt');
          await addFileWithoutCommitting(d, fileName: 'file2.txt');

          // Let's stage only one file
          await stageFile(d, 'file1.txt');

          // Commit the file without additional staging
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: false,
            ggLog: messages.add,
          );

          // Only file1.txt should be committed
          expect(await modifiedFiles(d), ['file2.txt']);
        });
      });

      group('should ammend files', () {
        test('when ammend = true', () async {
          // Let's modify a file
          await addAndCommitSampleFile(d, fileName: 'file1.txt');

          // Count the number of commits
          final count0 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );

          // Modify the file again
          File('${d.path}/file1.txt').writeAsStringSync('Change 2!');

          // Commit the file again with ammend = false
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ammend: false,
            ggLog: messages.add,
          );

          // Commit count should have increased
          final count1 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );
          expect(count1, count0 + 1);

          // Make another change
          File('${d.path}/file1.txt').writeAsStringSync('Change 3!');

          // Commit the file again with ammend = true
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ammend: true,
            ggLog: messages.add,
          );

          // Commit count should be the same
          final count2 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(count2, count1);
        });

        test(
          'when ammendWhenNotPushed is true and state is not yet pushed',
          () async {
            // Let's modify a file
            await addAndCommitSampleFile(d, fileName: 'file1.txt');

            // Count the number of commits
            final count0 = await commitCount.get(
              ggLog: messages.add,
              directory: d,
            );

            // Modify the file again
            File('${d.path}/file1.txt').writeAsStringSync('Change 2!');

            // Commit the file again with ammendWhenNotPushed = true
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: true,
              ammendWhenNotPushed: true,
              ggLog: messages.add,
            );

            // Commit count should not have increased
            // because we did not push yet.
            final count1 = await commitCount.get(
              ggLog: messages.add,
              directory: d,
            );
            expect(count1, count0);

            // Push the current state
            await pushLocalChanges(d);

            // Make another change
            File('${d.path}/file1.txt').writeAsStringSync('Change 3!');

            // Commit the file again with ammendWhenNotPushed = true
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: true,
              ammendWhenNotPushed: true,
              ggLog: messages.add,
            );

            // Commit count should have increased
            // because we did push the previous release
            final count2 = await commitCount.get(
              ggLog: messages.add,
              directory: d,
            );

            expect(count2, count1 + 1);
          },
        );
      });
    });

    group('exec(directory, ggLog)', () {
      group('with ammend=false', () {
        test('should call commit', () async {
          final runner = CommandRunner<void>('gg', 'Test');
          runner.addCommand(commit);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');
          expect(await modifiedFiles(d), ['file1.txt']);

          // Commit the file
          await runner.run(
            ['commit', '-i', d.path, '-m', 'Commit message', '-s'],
          );

          expect(await modifiedFiles(d), <String>[]);
        });
      });

      group('with ammend=true', () {
        test('should call commit --ammend', () async {
          final runner = CommandRunner<void>('gg', 'Test');
          runner.addCommand(commit);

          // Make first commit
          await addAndCommitSampleFile(d, fileName: 'file1.txt');

          // Count the commits
          final count0 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );
          expect(count0, 2);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');
          expect(await modifiedFiles(d), ['file1.txt']);

          // Commit the file
          await runner.run(
            ['commit', '-i', d.path, '-m', 'Commit message', '-s', '-a'],
          );

          // Everything is committed
          expect(await modifiedFiles(d), <String>[]);

          // Commit count should be the same
          final count1 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );
          expect(count1, count0);
        });
      });
    });
  });
}
