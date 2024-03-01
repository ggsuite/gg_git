// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/base/gg_dir_base.dart';
import 'package:gg_process/gg_process.dart';
import 'package:test/test.dart';

import '../commands/test_helpers.dart';

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late GgDirCommandExample ggDirCommand;
  late Directory d;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    d = initTestDir();

    ggDirCommand = GgDirCommandExample(
      log: (msg) {
        messages.add(msg);
      },
    );
    runner.addCommand(ggDirCommand);
  }

  // ...........................................................................
  setUp(() {
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  group('GgDirCommandExample', () {
    // #########################################################################
    group('run(), isCommited()', () {
      group('should throw', () {
        // .....................................................................
        test('if directory does not exist', () async {
          initCommand();
          await expectLater(
            runner.run(['example', '--directory', 'xyz']),
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
    });

    // #########################################################################
    test('should succeed', () async {
      initTestDir();
      initCommand();
      await runner.run(['example', '--directory', d.path]);
      expect(
        messages,
        ['Example executed for "test".'],
        reason: messages.join('\n'),
      );
      expect(exitCode, 0);
    });
  });
}
