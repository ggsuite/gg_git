// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_git/src/commands/commit.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late Commit commit;
  final messages = <String>[];
  const commitMessage = 'My commit message';

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    commit = Commit(ggLog: messages.add);
    await initGit(d);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('Commit', () {
    group('commit', () {
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
          await initUncommittedFile(d, fileName: 'file1.txt');

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
          await initUncommittedFile(d, fileName: 'file1.txt');

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
          await initUncommittedFile(d, fileName: 'file1.txt');

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
      });

      group('should commit files', () {
        test('with doStage = true', () async {
          // Let's modify a file
          await initUncommittedFile(d, fileName: 'file1.txt');

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
          await initUncommittedFile(d, fileName: 'file1.txt');
          await initUncommittedFile(d, fileName: 'file2.txt');

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
    });

    group('exec(directory, ggLog)', () {
      test('should call commit', () async {
        final runner = CommandRunner<void>('gg', 'Test');
        runner.addCommand(commit);

        // Let's modify a file
        await initUncommittedFile(d, fileName: 'file1.txt');
        expect(await modifiedFiles(d), ['file1.txt']);

        // Commit the file
        await runner.run(
          ['commit', '-i', d.path, '-m', 'Commit message', '-s'],
        );

        expect(await modifiedFiles(d), <String>[]);
      });
    });
  });
}
