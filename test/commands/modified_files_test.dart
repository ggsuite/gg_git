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
    await initGit(d);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('ModifiedFiles', () {
    group('get', () {
      test('should return a list of modified files', () async {
        // Initially no files are modified
        var result = await modifiedFiles.get(directory: d, ggLog: messages.add);
        expect(result, isEmpty);

        // Let's modify a file
        await initUncommittedFile(d, fileName: 'file1.txt');

        // Now we should have one modified file
        result = await modifiedFiles.get(directory: d, ggLog: messages.add);
        expect(result, ['file1.txt']);

        // Let's modify another file
        await initUncommittedFile(d, fileName: 'file2.txt');
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

      group('should throw', () {
        test('when something goes wrong while calling git', () async {
          final processWrapper = MockGgProcessWrapper();

          // Mock the processWrapper to return an error
          final modifiedFiles = ModifiedFiles(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );

          when(
            () => modifiedFiles.processWrapper.run(
              'git',
              ['status', '-s'],
              workingDirectory: d.path,
            ),
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
            contains('Exception: Could not retrieve modified files: My Error'),
          );
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
        await initUncommittedFile(d, fileName: 'file1.txt');

        // Now we should have one modified file
        await runner.run(['modified-files', '-i', d.path]);
        expect(messages.last, 'file1.txt');

        // Let's modify another file
        await initUncommittedFile(d, fileName: 'file2.txt');
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
      });
    });
  });
}
