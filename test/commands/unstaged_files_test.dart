// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late UnstagedFiles unstagedFiles;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    unstagedFiles = UnstagedFiles(ggLog: messages.add);
    await initGit(d);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('UnstagedFiles', () {
    group('get(directory, force, ignoreFiles)', () {
      test('should return a list of unstaged files', () async {
        // Initially no files are unstaged
        var result = await unstagedFiles.get(directory: d, ggLog: messages.add);
        expect(result, isEmpty);

        // Let's add an unstaged file
        await addFileWithoutCommitting(d, fileName: 'file1.txt');

        // Now we should have one unstaged file
        result = await unstagedFiles.get(directory: d, ggLog: messages.add);
        expect(result, ['file1.txt']);

        // Let's modify another file
        await addFileWithoutCommitting(d, fileName: 'file2.txt');
        result = await unstagedFiles.get(directory: d, ggLog: messages.add);
        expect(result, ['file1.txt', 'file2.txt']);

        // Commit the first file
        await commitFile(d, 'file1.txt', message: 'Commit message');
        result = await unstagedFiles.get(directory: d, ggLog: messages.add);
        expect(result, ['file2.txt']);

        // Stage the second file -> Should not be shown as unstaged
        await stageFile(d, 'file2.txt');
        result = await unstagedFiles.get(directory: d, ggLog: messages.add);
        expect(result, isEmpty);

        // Commit the second file
        await commitFile(d, 'file2.txt', message: 'Commit message');
        result = await unstagedFiles.get(directory: d, ggLog: messages.add);
        expect(result, isEmpty);
      });
    });

    group('should throw', () {
      group('when something goes wrong while calling', () {
        test('git diff --name-only', () async {
          final processWrapper = MockGgProcessWrapper();

          // Mock the processWrapper to return an error
          final stagedFiles = UnstagedFiles(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );

          when(
            () => stagedFiles.processWrapper.run('git', [
              'diff',
              '--name-only',
            ], workingDirectory: d.path),
          ).thenAnswer((_) async => ProcessResult(1, 1, '', 'My Error'));

          // Call the method
          late String exception;
          try {
            await stagedFiles.get(directory: d, ggLog: messages.add);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            contains('Exception: Could not retrieve unstaged files: My Error'),
          );
        });

        test('git ls-files', () async {
          final processWrapper = MockGgProcessWrapper();

          when(
            () => processWrapper.run('git', [
              'diff',
              '--name-only',
            ], workingDirectory: d.path),
          ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

          // Mock git rev-list returns an error

          when(
            () => processWrapper.run('git', [
              'ls-files',
              '--others',
              '--exclude-standard',
            ], workingDirectory: d.path),
          ).thenAnswer((_) async => ProcessResult(1, 1, '', 'My Error'));

          // Init command
          final stagedFiles = UnstagedFiles(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );

          // Call the method
          late String exception;
          try {
            await stagedFiles.get(directory: d, ggLog: messages.add);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            contains('Exception: Could not retrieve unstaged files: My Error'),
          );
        });
      });
    });
  });

  group('exec(directory, ggLog)', () {
    test('should return a list of unstaged files', () async {
      final runner = CommandRunner<void>('gg', 'Test');
      runner.addCommand(unstagedFiles);

      // Initially no files are unstaged
      await unstagedFiles.exec(directory: d, ggLog: messages.add);
      expect(messages, ['']);

      // Let's modify a file
      await addFileWithoutCommitting(d, fileName: 'file1.txt');

      // Now we should have one unstaged file
      await runner.run(['unstaged-files', '-i', d.path]);
      expect(messages.last, 'file1.txt');

      // Let's modify another file
      await addFileWithoutCommitting(d, fileName: 'file2.txt');
      await runner.run(['unstaged-files', '-i', d.path]);
      expect(messages.last, 'file1.txt\nfile2.txt');

      // Commit the first file
      await commitFile(d, 'file1.txt', message: 'Commit message');
      await runner.run(['unstaged-files', '-i', d.path]);
      expect(messages.last, 'file2.txt');

      // Stage the second file -> Should not be shown as unstaged
      await stageFile(d, 'file2.txt');
      await runner.run(['unstaged-files', '-i', d.path]);
      expect(messages.last, '');
    });
  });
}
