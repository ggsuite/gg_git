// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart' as h;

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsCommitted isCommitted;
  late Directory testDir;

  // ...........................................................................
  Future<void> initTestDir() async => testDir = await h.initTestDir();
  Future<void> initGit() => h.initGit(testDir);
  Future<void> initUncommittedFile() => h.initUncommittedFile(testDir);

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    isCommitted = IsCommitted(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(isCommitted);
  }

  // ...........................................................................
  setUp(() {
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  group('IsCommitted', () {
    // #########################################################################
    group('run(), get()', () {
      test('should throw if "git status" fails', () async {
        final failingProcessWrapper = MockGgProcessWrapper();

        await initTestDir();
        await initGit();
        initCommand(processWrapper: failingProcessWrapper);

        when(
          () => failingProcessWrapper.run(
            any(),
            any(),
            workingDirectory: testDir.path,
          ),
        ).thenAnswer(
          (_) async => ProcessResult(
            1,
            1,
            'git status failed',
            'git status failed',
          ),
        );

        expect(
          () async =>
              await runner.run(['is-committed', '--input', testDir.path]),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: Could not run "git status" in "test".',
            ),
          ),
        );
      });

      // .......................................................................
      group('should return', () {
        group('false', () {
          test('if there are uncommitted changes', () async {
            await initTestDir();
            await initGit();
            await initUncommittedFile();
            initCommand();

            await expectLater(
              runner.run(['is-committed', '--input', testDir.path]),
              throwsA(
                isA<Exception>().having(
                  (e) => e.toString(),
                  'message',
                  contains('There are uncommmited changes.'),
                ),
              ),
            );
          });
        });

        // .....................................................................
        group('true', () {
          group('if everything is committed', () {
            test('with inputDir from --input args', () async {
              await initTestDir();
              await initGit();
              initCommand();
              await runner.run(['is-committed', '--input', testDir.path]);
              expect(messages.last, contains('✅ Everything is committed.'));
            });

            test('with inputDir taken from constructor', () async {
              await initTestDir();
              await initGit();
              initCommand();
              final result = await isCommitted.get(
                directory: testDir,
                ggLog: messages.add,
              );
              expect(result, isTrue);
            });
          });
        });
      });
    });
  });
}
