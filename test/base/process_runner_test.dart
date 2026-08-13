// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/gg_git.dart';
import 'package:test/test.dart';

void main() {
  group('defaultProcessRunner', () {
    test('runs a process and returns its result', () async {
      final result = await defaultProcessRunner('git', ['--version']);
      expect(result.exitCode, 0);
      expect(result.stdout.toString(), contains('git version'));
    });

    test('forwards workingDirectory, environment and runInShell', () async {
      final result = await defaultProcessRunner(
        'git',
        ['rev-parse', '--show-toplevel'],
        workingDirectory: '.',
        environment: const {'GG_MULTI_CORE_TEST': '1'},
        runInShell: false,
      );
      expect(result.exitCode, 0);
    });

    test('is assignable to ProcessRunner', () {
      const ProcessRunner runner = defaultProcessRunner;
      expect(runner, isNotNull);
    });
  });
}
