// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late IsFeatureBranch isFeatureBranch;
  late CommandRunner<void> runner;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    isFeatureBranch = IsFeatureBranch(ggLog: messages.add);
    runner = CommandRunner<void>('test', 'test');
    runner.addCommand(isFeatureBranch);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('IsFeatureBranch', () {
    group('get()', () {
      test('should return false when current branch is main', () async {
        await initGit(d);

        final result = await isFeatureBranch.get(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isFalse);
      });

      test('should return false when current branch is master', () async {
        await initGit(d);
        await createBranch(d, 'master');

        final result = await isFeatureBranch.get(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isFalse);
      });

      test('should return true when '
          'current branch is a feature branch', () async {
        await initGit(d);
        await createBranch(d, 'feat_abc');

        final result = await isFeatureBranch.get(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isTrue);
      });
    });

    group('exec(directory, ggLog)', () {
      test('should print the evaluation result', () async {
        await initGit(d);

        await runner.run(['is-feature-branch', '-i', d.path]);
        expect(messages.last, 'false');

        await createBranch(d, 'feature/demo');
        await runner.run(['is-feature-branch', '-i', d.path]);
        expect(messages.last, 'true');
      });
    });
  });
}
