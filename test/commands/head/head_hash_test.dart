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
  late HeadHash headHash;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    headHash = HeadHash(ggLog: messages.add);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('HeadHash', () {
    group('get(directory, offset)', () {
      group('should throw', () {
        test('when the directory is not a git repo', () {
          expect(
            () => headHash.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.toString(),
                'toString()',
                contains('Directory "test" is not a git repository.'),
              ),
            ),
          );
        });
        group('when not everything is committed', () {
          test('and --force is false', () async {
            // Init git
            await initGit(d);

            // Add an uncommitted file
            await initUncommittedFile(d);

            // Getting the head hash should throw
            await expectLater(
              () =>
                  headHash.get(directory: d, ggLog: messages.add, force: false),
              throwsA(
                isA<Exception>().having(
                  (e) => e.toString(),
                  'toString()',
                  contains('Exception: Not everything is committed.'),
                ),
              ),
            );
          });
        });

        test('when the offset has a wrong format', () async {
          late String exception;
          try {
            await headHash.get(
              directory: d,
              ggLog: messages.add,
              offset: -1,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Invalid offset -1. Offset must be a positive integer.',
          );
        });

        test('when something goes wrong while getting the tag', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Mock IsCommitted
          final isCommited = MockIsCommitted();
          when(() => isCommited.get(directory: d, ggLog: any(named: 'ggLog')))
              .thenAnswer((_) => Future.value(true));

          // Getting the head hash should throw
          final failingProcessWrapper = MockGgProcessWrapper();

          // Mock a failing process
          when(
            () => failingProcessWrapper.run(
              any(),
              any(),
              workingDirectory: d.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(
              1,
              1,
              'stdout',
              'stderr',
            ),
          );

          // Run headHash.get and check if it throws
          headHash = HeadHash(
            ggLog: messages.add,
            processWrapper: failingProcessWrapper,
            isCommitted: isCommited,
          );

          await expectLater(
            () => headHash.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'toString()',
                contains(
                  'Exception: Could not read the head hash: stderr',
                ),
              ),
            ),
          );
        });
      });

      group('should return the head hash', () {
        test('when nothing is committed at all', () async {
          await initGit(d);
          final hash = await headHash.get(directory: d, ggLog: messages.add);
          expect(hash, HeadHash.initialHash);
        });

        test('when everything is committed', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Getting the head hash should work
          final hash = await headHash.get(directory: d, ggLog: messages.add);
          expect(hash, isNotEmpty);
        });

        test('when not everything is committed but --force is true', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Getting the head hash should work
          final hash = await headHash.get(directory: d, ggLog: messages.add);
          expect(hash, isNotEmpty);

          // Now let's add an uncommitted file
          await initUncommittedFile(d);

          // Getting the head with --force should return the hash of the
          // last commit no matter if everything is committed or not
          final hash2 = await headHash.get(
            directory: d,
            ggLog: messages.add,
            force: true,
          );

          expect(hash2, hash);
        });
      });

      group('should allow to get the hashes of commits before head', () {
        test('when offset is used', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);
          final oldHead = await headHash.get(directory: d, ggLog: messages.add);

          // Do another commit
          await updateAndCommitSampleFile(d);
          final newHead = await headHash.get(directory: d, ggLog: messages.add);

          // Get the hash of the commit before the head
          final hash = await headHash.get(
            directory: d,
            ggLog: messages.add,
            offset: 1,
          );

          expect(hash, oldHead);
          expect(newHead, isNot(oldHead));
        });
      });
    });

    group('exec(directory)', () {
      group('should allow to run the command', () {
        test('programmatically', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          await headHash.exec(directory: d, ggLog: messages.add);
          final oldHead = messages.last;
          expect(oldHead, isNotEmpty);

          // Make another commit
          await updateAndCommitSampleFile(d);

          // Run the command again
          await headHash.exec(directory: d, ggLog: messages.add);
          final newHead = messages.last;

          // Get the head before the last commit
          await headHash.exec(
            directory: d,
            ggLog: messages.add,
            offset: 1,
          );

          final oldHead2 = messages.last;
          expect(oldHead2, oldHead);
          expect(newHead, isNot(oldHead));
        });

        test('using cli', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headHash);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          await runner.run(['hash', '-i', d.path]);
          final oldHead = messages.last;
          expect(oldHead, isNotEmpty);

          // Make another commit
          await updateAndCommitSampleFile(d);

          // Run the command again
          await runner.run(['hash', '-i', d.path]);
          final newHead = messages.last;

          // Get the head before the last commit
          await runner.run(['hash', '-i', d.path, '-o', '1']);

          final oldHead2 = messages.last;
          expect(oldHead2, oldHead);
          expect(newHead, isNot(oldHead));
        });
      });

      group('should throw', () {
        test('when the offset is a negative int', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headHash);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          late String exception;

          try {
            await runner.run(['hash', '-i', d.path, '-o', '-1']);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Invalid offset -1. '
            'Offset must be a positive integer.',
          );
        });

        test('when the offset is a string', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headHash);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          late String exception;

          try {
            await runner.run(['hash', '-i', d.path, '-o', 'a']);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Invalid offset a. Offset must be a positive integer.',
          );
        });
      });
    });
  });
}
