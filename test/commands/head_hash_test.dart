// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late HeadHash headHash;
  final messages = <String>[];

  setUp(() {
    messages.clear();
    d = initTestDir();
    headHash = HeadHash(ggLog: messages.add);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('HeadHash', () {
    group('get(directory)', () {
      // const HeadHash();
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
        test('when not everything is commited', () async {
          // Init git
          await initGit(d);

          // Add an uncommitted file
          await initUncommittedFile(d);

          // Getting the head hash should throw
          await expectLater(
            () => headHash.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'toString()',
                contains('Exception: Not everything is commited.'),
              ),
            ),
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
        test('when everything is commited', () async {
          // Init git
          await initGit(d);
          await addAndCommitSampleFile(d);

          // Getting the head hash should work
          final hash = await headHash.get(directory: d, ggLog: messages.add);
          expect(hash, isNotEmpty);
        });
      });
    });

    group('run(directory)', () {
      test('should allow to run the command from cli', () async {
        // Init git
        await initGit(d);
        await addAndCommitSampleFile(d);

        // Run the command
        await headHash.exec(directory: d, ggLog: messages.add);
        expect(messages.last, isNotEmpty);
      });
    });
  });
}
