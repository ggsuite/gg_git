// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../bin/gg_git.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart';

void main() {
  late Directory d;

  setUp(() {
    d = initTestDir();
  });

  group('bin/gg_git.dart', () {
    // #########################################################################

    test('should be executable', () async {
      await initGit(d);

      // Execute bin/gg_git.dart and check if it prints help
      final result = await Process.run(
        './bin/gg_git.dart',
        ['get-tags', '--head-only', '--input', d.path],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      final expectedMessages = [
        'No head tags found.\n',
      ];

      final stdout = result.stdout as String;

      for (final msg in expectedMessages) {
        expect(stdout, contains(msg));
      }
    });
  });

  // ###########################################################################
  group('run(args, log)', () {
    test('should print "value"', () async {
      await initGit(d);

      // Execute bin/gg_git.dart and check if it prints "value"
      final messages = <String>[];
      await run(args: ['get-tags', '--input', d.path], ggLog: messages.add);

      expect(messages.last, 'No tags found.');
    });
  });
}
