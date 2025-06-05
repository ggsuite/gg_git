// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_git/src/commands/head/head_time_stamp.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late HeadTimeStamp headTimeStamp;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    headTimeStamp = HeadTimeStamp(ggLog: messages.add);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('HeadTimeStamp', () {
    group('get(directory, offset)', () {
      group('should throw', () {
        test('when the directory is not a git repo', () {
          expect(
            () => headTimeStamp.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.toString(),
                'toString()',
                contains('Directory "test" is not a git repository.'),
              ),
            ),
          );
        });
        test('when not everything is committed', () async {
          // Init git
          await initGit(d);

          // Add an uncommitted file
          await addFileWithoutCommitting(d);

          // Getting the head commit message should throw
          await expectLater(
            () => headTimeStamp.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'toString()',
                contains('Exception: Not everything is committed.'),
              ),
            ),
          );
        });

        test('when the offset has a wrong format', () async {
          late String exception;
          try {
            await headTimeStamp.get(
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
          headTimeStamp = HeadTimeStamp(
            ggLog: messages.add,
            processWrapper: failingProcessWrapper,
            isCommitted: isCommited,
          );

          late String exception;
          try {
            await headTimeStamp.get(directory: d, ggLog: messages.add);
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            contains(
              'Exception: Could not read the timestamp from head hash: stderr',
            ),
          );
        });
      });

      group('should return the head commit message', () {
        test('when everything is committed', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Getting the head commit message should work
          final message = await headTimeStamp.get(
            directory: d,
            ggLog: messages.add,
          );
          expect(message, isNot(0));
        });
      });

      group('should allow to get the timestamp of commits before head', () {
        test('when offset is used', () async {
          // Get linux time stamp
          final timeStamp0 = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          await initGit(d);
          await addAndCommitSampleFile(d);

          // Get time stamp
          final timeStamp1 = await headTimeStamp.get(
            directory: d,
            ggLog: messages.add,
          );
          expect(timeStamp1, greaterThanOrEqualTo(timeStamp0));

          // Wait 100ms
          await Future<void>.delayed(const Duration(milliseconds: 100));

          // Do another commit
          await updateAndCommitSampleFile(d, message: 'New commit');

          // Get time stamp
          final timeStamp2 = await headTimeStamp.get(
            directory: d,
            ggLog: messages.add,
          );

          // TimeStampe should be at least 100ms later
          expect(timeStamp2, greaterThanOrEqualTo(timeStamp1));
        });
      });
    });

    group('exec(directory)', () {
      group('should allow to run the command from cli', () {
        test('programmatically', () async {
          // Get linux time stamp
          final timeStamp0 = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d, message: 'message 1');

          // Run the command
          await headTimeStamp.exec(directory: d, ggLog: messages.add);
          final timeStampString = messages.last;
          expect(timeStampString, isNotEmpty);

          // Parse time stamp
          final timeStamp = int.parse(timeStampString);
          expect(timeStamp, greaterThanOrEqualTo(timeStamp0));
        });

        test('using cli', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headTimeStamp);

          // Get linux time stamp
          final timeStamp0 = DateTime.now().millisecondsSinceEpoch ~/ 1000;

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d, message: 'message 1');

          // Run the command
          await runner.run(['time-stamp', '-i', d.path]);
          final timeStampString1 = messages.last;
          expect(timeStampString1, isNotEmpty);

          // Parse time stamp
          final timeStamp = int.parse(timeStampString1);
          expect(timeStamp, greaterThanOrEqualTo(timeStamp0));

          // Make another commit
          await updateAndCommitSampleFile(d, message: 'message 2');

          // Run the command
          await runner.run(['time-stamp', '-i', d.path, '-o', '1']);
          final timeStampString2 = messages.last;
          expect(timeStampString2, timeStampString1);
        });
      });

      group('should throw', () {
        test('when the offset is a negative int', () async {
          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(headTimeStamp);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          late String exception;

          try {
            await runner.run(['time-stamp', '-i', d.path, '-o', '-1']);
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
          runner.addCommand(headTimeStamp);

          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Run the command
          late String exception;

          try {
            await runner.run(['time-stamp', '-i', d.path, '-o', 'a']);
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
