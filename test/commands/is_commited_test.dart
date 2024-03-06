// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/is_commited.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'test_helpers.dart' as h;

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsCommited ggIsCommited;
  late Directory testDir;

  // ...........................................................................
  void initTestDir() => testDir = h.initTestDir();
  Future<void> initGit() => h.initGit(testDir);
  void initUncommitedFile() => h.initUncommitedFile(testDir);

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    ggIsCommited = IsCommited(
      log: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(ggIsCommited);
  }

  // ...........................................................................
  setUp(() {
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  group('GgIsCommited', () {
    // #########################################################################
    group('run(), isCommited()', () {
      // .......................................................................
      test('should throw if "git status" fails', () async {
        final failingProcessWrapper = MockGgProcessWrapper();

        initTestDir();
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

        await expectLater(
          runner.run(['is-commited', '--input', testDir.path]),
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
      test('if there are uncommited changes', () async {
        initTestDir();
        await initGit();
        initUncommitedFile();
        initCommand();

        await expectLater(
          runner.run(['is-commited', '--input', testDir.path]),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              'Exception: There are uncommited changes.',
            ),
          ),
        );
      });
    });

    // #########################################################################
    group('should return', () {
      // .......................................................................
      test('true if everything is commited', () async {
        initTestDir();
        await initGit();
        initCommand();
        await runner.run(['is-commited', '--input', testDir.path]);
        expect(messages, ['Everything is commited.']);
      });
    });
  });
}
