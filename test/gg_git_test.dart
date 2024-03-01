// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];

  group('GgGit()', () {
    // #########################################################################
    group('exec()', () {
      test('description of the test ', () async {
        final ggGit = GgGit(param: 'foo', log: (msg) => messages.add(msg));

        await ggGit.exec();
      });
    });

    // #########################################################################
    group('ggGit', () {
      test('should allow to run the code from command line', () async {
        final ggGit = GgGitCmd(log: (msg) => messages.add(msg));

        final CommandRunner<void> runner = CommandRunner<void>(
          'ggGit',
          'Description goes here.',
        )..addCommand(ggGit);

        await runner.run(['ggGit', '--param', 'foo']);
      });
    });
  });
}
