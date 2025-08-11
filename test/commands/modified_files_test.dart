// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/modified_files.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late ModifiedFiles modifiedFiles;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    modifiedFiles = ModifiedFiles(ggLog: messages.add);
    await initGit(d, isEolLfEnabled: false);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('ModifiedFiles', () {
    group('get(directory, force, ignoreFiles)', () {
      group('should return a list of modified files', () {
        test('with force = false', () async {
          // Initially no files are modified
          var result = await modifiedFiles.get(
            directory: d,
            ggLog: messages.add,
          );
          expect(result, isEmpty);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Now we should have one modified file
          result = await modifiedFiles.get(directory: d, ggLog: messages.add);
          expect(result, ['file1.txt']);

          // Let's modify another file
          await addFileWithoutCommitting(d, fileName: 'file2.txt');
          result = await modifiedFiles.get(directory: d, ggLog: messages.add);
          expect(result, ['file1.txt', 'file2.txt']);

          // Commit the first file
          await commitFile(d, 'file1.txt', message: 'Commit message');
          result = await modifiedFiles.get(directory: d, ggLog: messages.add);
          expect(result, ['file2.txt']);

          // Stage the second file -> Should still be shown as modified
          await stageFile(d, 'file2.txt');
          result = await modifiedFiles.get(directory: d, ggLog: messages.add);
          expect(result, ['file2.txt']);

          // Commit the second file
          await commitFile(d, 'file2.txt', message: 'Commit message');
          result = await modifiedFiles.get(directory: d, ggLog: messages.add);
          expect(result, isEmpty);
        });

        group('with force = true', () {
          test('and multiple files ignored', () async {
            // Initially no files are modified
            var result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, isEmpty);

            // Let's modify a file
            await addFileWithoutCommitting(d, fileName: 'file1.txt');

            // Now we should have one modified file
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, ['file1.txt']);

            // Request again, but with file1.txt ignored
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
              ignoreFiles: ['file1.txt'],
            );
            expect(result, isEmpty);

            // Let's modify another file
            await addFileWithoutCommitting(d, fileName: 'file2.txt');
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, ['file1.txt', 'file2.txt']);

            // Ignore the other file
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
              ignoreFiles: ['file2.txt'],
            );
            expect(result, ['file1.txt']);

            // Commit the first file
            await commitFile(d, 'file1.txt', message: 'Commit message');
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, ['file2.txt']);

            // Stage the second file -> Should still be shown as modified
            await stageFile(d, 'file2.txt');
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, ['file2.txt']);

            // Commit the second file
            // With force = false, the file should not be shown anymore
            await commitFile(d, 'file2.txt', message: 'Commit message');
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: false,
            );
            expect(result, isEmpty);

            // Get the modified files
            // with force = true,
            // the files changed in the last commit should be shown
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, ['file2.txt']);

            // Try again with force = true
            // and ignore file2.txt
            // The changes of the previous commit should be returned.
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
              ignoreFiles: ['file2.txt'],
            );
            expect(result, ['file1.txt']);
          });

          test('and only ignored files modified', () async {
            // Make an initial commit
            await addAndCommitSampleFile(d, fileName: 'file1.txt');

            // Asking for modified files should give the modified file
            var result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
            );
            expect(result, ['file1.txt']);

            // Add another ignored file and commit it
            await addAndCommitSampleFile(d, fileName: 'ignore.txt');

            // Asking for modified files should give the modified file
            // when not added to ignored files
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
              ignoreFiles: [],
            );
            expect(result, ['ignore.txt']);

            // Asking for modified files
            // should give the previous modified files
            // when a commit only contains ignored files
            // and force is true
            result = await modifiedFiles.get(
              directory: d,
              ggLog: messages.add,
              force: true,
              ignoreFiles: ['ignore.txt'],
            );
            expect(result, ['file1.txt']);
          });

          for (final returnDeleted in [true, false]) {
            group('and deletedFiles', () {
              test('with ignoreDeleted = $returnDeleted', () async {
                // Commit two files
                await addAndCommitSampleFile(d, fileName: 'file1.txt');
                await addAndCommitSampleFile(d, fileName: 'file2.txt');

                // Delete one of the files and commit
                await deleteFileAndCommit(d, 'file1.txt');

                // Modify the other file and ammend
                await updateAndCommitSampleFile(
                  d,
                  fileName: 'file2.txt',
                  ammend: true,
                );

                // Get the modified files with ignoreDeleted = true|false
                final files = await modifiedFiles.get(
                  directory: d,
                  ggLog: messages.add,
                  force: true,
                  returnDeleted: returnDeleted,
                );

                // Check, if the right files were returned
                if (returnDeleted) {
                  expect(files, ['file1.txt', 'file2.txt']);
                } else {
                  expect(files, ['file2.txt']);
                }
              });
            });
          }
        });
      });

      group('should throw', () {
        group('when something goes wrong while calling', () {
          test(' git status', () async {
            final processWrapper = MockGgProcessWrapper();

            // Mock the processWrapper to return an error
            final modifiedFiles = ModifiedFiles(
              ggLog: messages.add,
              processWrapper: processWrapper,
            );

            when(
              () => modifiedFiles.processWrapper.run('git', [
                'status',
                '-s',
              ], workingDirectory: d.path),
            ).thenAnswer((_) async => ProcessResult(1, 1, '', 'My Error'));

            // Call the method
            late String exception;
            try {
              await modifiedFiles.get(directory: d, ggLog: messages.add);
            } catch (e) {
              exception = e.toString();
            }

            expect(
              exception,
              contains(
                'Exception: Could not retrieve modified files: My Error',
              ),
            );
          });

          test(' git rev-list', () async {
            final processWrapper = MockGgProcessWrapper();

            when(
              () => processWrapper.run('git', [
                'status',
                '-s',
              ], workingDirectory: d.path),
            ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

            // Mock git rev-list returns an error

            when(
              () => processWrapper.run('git', [
                'rev-list',
                '-n',
                '1',
                '--all',
              ], workingDirectory: d.path),
            ).thenAnswer((_) async => ProcessResult(1, 1, '', 'My Error'));

            // Init command
            final modifiedFiles = ModifiedFiles(
              ggLog: messages.add,
              processWrapper: processWrapper,
            );

            // Call the method
            late String exception;
            try {
              await modifiedFiles.get(
                directory: d,
                ggLog: messages.add,
                force: true,
              );
            } catch (e) {
              exception = e.toString();
            }

            expect(
              exception,
              contains('Exception: Error while retrieving revisions: My Error'),
            );
          });
        });
      });
    });

    group('exec(directory, ggLog)', () {
      test('should return a list of modified files', () async {
        final runner = CommandRunner<void>('gg', 'Test');
        runner.addCommand(modifiedFiles);

        // Initially no files are modified
        await modifiedFiles.exec(directory: d, ggLog: messages.add);
        expect(messages, ['']);

        // Let's modify a file
        await addFileWithoutCommitting(d, fileName: 'file1.txt');

        // Now we should have one modified file
        await runner.run(['modified-files', '-i', d.path]);
        expect(messages.last, 'file1.txt');

        // Let's modify another file
        await addFileWithoutCommitting(d, fileName: 'file2.txt');
        await runner.run(['modified-files', '-i', d.path]);
        expect(messages.last, 'file1.txt\nfile2.txt');

        // Commit the first file
        await commitFile(d, 'file1.txt', message: 'Commit message');
        await runner.run(['modified-files', '-i', d.path]);
        expect(messages.last, 'file2.txt');

        // Stage the second file -> Should still be shown as modified
        await stageFile(d, 'file2.txt');
        await runner.run(['modified-files', '-i', d.path]);
        expect(messages.last, 'file2.txt');

        // Commit the second file
        await commitFile(d, 'file2.txt', message: 'Commit message');
        await runner.run(['modified-files', '-i', d.path]);
        expect(messages.last, isEmpty);

        // Try again with force = true
        await runner.run(['modified-files', '-i', d.path, '--force']);
        expect(messages.last, 'file2.txt');
      });
    });
  });
}
