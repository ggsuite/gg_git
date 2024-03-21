// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_process/gg_process.dart';
import 'package:test/test.dart';

import 'package:gg_git/src/test_helpers/test_helpers.dart';

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late GgGitCommandExample ggGit;
  late Directory d;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    ggGit = GgGitCommandExample(
      log: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(ggGit);
  }

  // ...........................................................................
  setUp(() {
    runner = CommandRunner<void>('test', 'test');
    d = initTestDir();
    messages.clear();
  });

  group('GgGitCommandExample', () {
    // #########################################################################
    group('run(), get()', () {
      group('should throw', () {
        // .....................................................................
        group('if directory does not exist', () {
          test('specified via --input', () async {
            initCommand();
            await expectLater(
              runner.run(['example', '--input', 'xyz']),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  'Directory "xyz" does not exist.',
                ),
              ),
            );
          });

          test('specified via constructor', () async {
            initCommand();
            await expectLater(
              ggGit.run(directory: Directory('xyz')),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  'Directory "xyz" does not exist.',
                ),
              ),
            );
          });
        });

        // .....................................................................
        test('if directory is not a git repository', () async {
          initTestDir();
          initCommand();
          await expectLater(
            runner.run(['example', '--input', d.path]),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'Directory "test" is not a git repository.',
              ),
            ),
          );
        });
      });
    });

    // #########################################################################
    test('should succeed', () async {
      initTestDir();
      await initGit(d);
      initCommand();
      await runner.run(['example', '--input', d.path]);
      expect(messages, ['Example executed for "test".']);
      expect(exitCode, 0);
    });
  });
}
