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
  late HeadMessage headMessage;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    headMessage = HeadMessage(ggLog: messages.add);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('HeadMessage', () {
    group('get(directory, offset)', () {
      group('should throw', () {
        test('when the directory is not a git repo', () {
          expect(
            () => headMessage.get(directory: d, ggLog: messages.add),
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
          test('and throwIfNotEverythingIsCommitted = true', () async {
            // Init git
            await initGit(d);

            // Add an uncommitted file
            await addFileWithoutCommitting(d);

            // Getting the head commit message should throw
            await expectLater(
              () => headMessage.get(directory: d, ggLog: messages.add),
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
            await headMessage.get(
              directory: d,
              ggLog: messages.add,
              offset: -2,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Invalid offset -2. Offset must be a positive integer.',
          );
        });

        test('when something goes wrong while getting the message', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Mock IsCommitted
          final isCommited = MockIsCommitted();
          when(
            () => isCommited.get(
              directory: d,
              ggLog: any(named: 'ggLog'),
            ),
          ).thenAnswer((_) => Future.value(true));

          // Getting the head commit message should throw
          final failingProcessWrapper = MockGgProcessWrapper();

          // Mock a failing process
          when(
            () => failingProcessWrapper.run(
              any(),
              any(),
              workingDirectory: d.path,
            ),
          ).thenAnswer((_) async => ProcessResult(1, 1, 'stdout', 'stderr'));

          // Run headMessage.get and check if it throws
          headMessage = HeadMessage(
            ggLog: messages.add,
            processWrapper: failingProcessWrapper,
            isCommitted: isCommited,
          );

          late String exception;
          try {
            await headMessage.get(directory: d, ggLog: messages.add);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            contains('Exception: Could not read the head message: stderr'),
          );
        });
      });

      group('should return the head commit message', () {
        test('when everything is committed', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Getting the head commit message should work
          final message = await headMessage.get(
            directory: d,
            ggLog: messages.add,
          );
          expect(message, isNotEmpty);
        });

        group('when not everything is committed', () {
          test('but throwIfNotEverythingIsCommitted = false', () async {
            // Init git
            await initGit(d);

            // Add an uncommitted file
            await addAndCommitSampleFile(
              d,
              fileName: 'test.txt',
              message: 'Last message',
            );

            // Modify the file
            await addFileWithoutCommitting(
              d,
              fileName: 'test.txt',
              content: 'xyz',
            );

            // Getting the head commit message should work,
            // also when not everything is committed
            // because throwIfNotEverythingIsCommitted = false
            final message = await headMessage.get(
              directory: d,
              ggLog: messages.add,
              throwIfNotEverythingIsCommitted: false,
            );

            expect(message, 'Last message');
          });
        });
      });

      group('should allow to get the messages of commits before head', () {
        test('when offset is used', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d, message: 'Old commit');
          final oldMessage = await headMessage.get(
            directory: d,
            ggLog: messages.add,
          );

          // Do another commit
          await updateAndCommitSampleFile(d, message: 'New commit');
          final newMessage = await headMessage.get(
            directory: d,
            ggLog: messages.add,
          );

          // Get the message of the commit before the head
          final message = await headMessage.get(
            directory: d,
            ggLog: messages.add,
            offset: 1,
          );

          expect(message, oldMessage);
          expect(newMessage, isNot(oldMessage));
        });
      });
    });

    group('exec(directory)', () {
      group('should allow to run the command from cli', () {
        test('programmatically', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d, message: 'message 1');

          // Run the command
          await headMessage.exec(directory: d, ggLog: messages.add);
          final oldMessage = messages.last;
          expect(oldMessage, isNotEmpty);

          // Make another commit
          await updateAndCommitSampleFile(d, message: 'message 2');

          // Run the command again
          await headMessage.exec(directory: d, ggLog: messages.add);
          final newMessage = messages.last;

          // Get the head before the last commit
          await headMessage.exec(directory: d, ggLog: messages.add, offset: 1);

          final oldMessage2 = messages.last;
          expect(oldMessage2, oldMessage);
          expect(newMessage, isNot(oldMessage));
        });

        test('using cli', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headMessage);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d, message: 'message 1');

          // Run the command
          await runner.run(['message', '-i', d.path]);
          final oldMessage = messages.last;
          expect(oldMessage, isNotEmpty);

          // Make another commit
          await updateAndCommitSampleFile(d, message: 'message 2');

          // Run the command again
          await runner.run(['message', '-i', d.path]);
          final newMessage = messages.last;

          // Get the head before the last commit
          await runner.run(['message', '-i', d.path, '-o', '1']);

          final oldMessage2 = messages.last;
          expect(oldMessage2, 'message 1');
          expect(oldMessage2, oldMessage);
          expect(newMessage, 'message 2');
        });
      });

      group('should throw', () {
        test('when the offset is a negative int', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headMessage);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          late String exception;

          try {
            await runner.run(['message', '-i', d.path, '-o', '-1']);
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
          runner.addCommand(headMessage);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          late String exception;

          try {
            await runner.run(['message', '-i', d.path, '-o', 'a']);
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
