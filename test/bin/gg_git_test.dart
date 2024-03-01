// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:test/test.dart';

import '../../bin/gg_git.dart';

void main() {
  group('bin/gg_git.dart', () {
    // #########################################################################

    test('should be executable', () async {
      // Execute bin/gg_git.dart and check if it prints help
      final result = await Process.run(
        './bin/gg_git.dart',
        ['version-from-git', '--head-only'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      final expectedMessages = [
        'No version tag found in head.',
      ];

      final stdout = result.stdout as String;

      for (final msg in expectedMessages) {
        expect(stdout, contains(msg));
      }
    });
  });

  // ###########################################################################
  group('run(args, log)', () {
    group('with args=[--param, value]', () {
      test('should print "value"', () async {
        // Execute bin/gg_git.dart and check if it prints "value"
        final messages = <String>[];
        await run(args: ['--param', '5'], log: messages.add);

        final expectedMessages = [
          'version-from-git',
          'Returns the version tag of the latest state or nothing '
              'if not tagged',
        ];

        for (final msg in expectedMessages) {
          expect(hasLog(messages, msg), isTrue);
        }
      });
    });
  });
}
