// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
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

      test('should return false when the current branch is the default '
          'branch declared by origin/HEAD, even if it is not main', () async {
        final (local, remote) = await initLocalAndRemoteGit();
        addTearDown(() {
          local.deleteSync(recursive: true);
          remote.deleteSync(recursive: true);
        });

        Future<void> git(List<String> args) async {
          final result = await ggRunProcess(
            'git',
            args,
            workingDirectory: local.path,
          );
          if (result.exitCode != 0) {
            throw Exception('git ${args.join(' ')} failed: ${result.stderr}');
          }
        }

        // The remote's default branch is develop, not main
        await createBranch(local, 'develop');
        await git(['push', '--set-upstream', 'origin', 'develop']);
        await git(['remote', 'set-head', 'origin', 'develop']);

        expect(
          await isFeatureBranch.get(directory: local, ggLog: messages.add),
          isFalse,
        );

        // main is a feature branch now
        await git(['checkout', 'main']);
        expect(
          await isFeatureBranch.get(directory: local, ggLog: messages.add),
          isTrue,
        );

        // A stale origin/HEAD is ignored: main counts as default again
        await git(['push', 'origin', '--delete', 'develop']);
        await git(['fetch', '--prune']);
        expect(
          await isFeatureBranch.get(directory: local, ggLog: messages.add),
          isFalse,
        );
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
