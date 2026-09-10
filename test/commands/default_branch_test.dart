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
  late Directory local;
  late Directory remote;
  late DefaultBranch defaultBranch;
  late CommandRunner<void> runner;
  final messages = <String>[];

  Future<void> git(Directory d, List<String> args) async {
    final result = await ggRunProcess('git', args, workingDirectory: d.path);
    if (result.exitCode != 0) {
      throw Exception('git ${args.join(' ')} failed: ${result.stderr}');
    }
  }

  setUp(() async {
    messages.clear();
    (local, remote) = await initLocalAndRemoteGit();
    defaultBranch = DefaultBranch(ggLog: messages.add);
    runner = CommandRunner<void>('test', 'test');
    runner.addCommand(defaultBranch);
  });

  tearDown(() {
    local.deleteSync(recursive: true);
    remote.deleteSync(recursive: true);
  });

  group('DefaultBranch', () {
    group('get()', () {
      test('should return the branch origin/HEAD points at', () async {
        await createBranch(local, 'develop');
        await git(local, ['push', '--set-upstream', 'origin', 'develop']);
        await git(local, ['remote', 'set-head', 'origin', 'develop']);

        // Whatever branch is checked out
        await git(local, ['checkout', 'main']);
        expect(
          await defaultBranch.get(directory: local, ggLog: messages.add),
          'develop',
        );

        await git(local, ['checkout', 'develop']);
        expect(
          await defaultBranch.get(directory: local, ggLog: messages.add),
          'develop',
        );
      });

      test('should fall back to main when origin/HEAD is not set', () async {
        await git(local, ['remote', 'set-head', 'origin', '--delete']);
        await createBranch(local, 'feat_abc');

        expect(
          await defaultBranch.get(directory: local, ggLog: messages.add),
          'main',
        );
      });

      test('should fall back to main when origin/HEAD points at a branch '
          'that does not exist on the remote anymore', () async {
        // A stale origin/HEAD, e.g. left behind after the remote's default
        // branch was renamed from develop to main.
        await git(local, [
          'symbolic-ref',
          'refs/remotes/origin/HEAD',
          'refs/remotes/origin/develop',
        ]);

        expect(
          await defaultBranch.get(directory: local, ggLog: messages.add),
          'main',
        );
      });

      test('should fall back to master when there is no main', () async {
        final d = await initTestDir();
        addTearDown(() => d.deleteSync(recursive: true));
        await initGit(d);
        await addAndCommitSampleFile(d);
        await git(d, ['branch', '-m', 'main', 'master']);
        await createBranch(d, 'feat_abc');

        expect(
          await defaultBranch.get(directory: d, ggLog: messages.add),
          'master',
        );
      });

      test(
        'should return the remote main when only the remote has it',
        () async {
          await createBranch(local, 'feat_abc');
          await git(local, ['branch', '-D', 'main']);
          await git(local, ['remote', 'set-head', 'origin', '--delete']);

          expect(
            await defaultBranch.get(directory: local, ggLog: messages.add),
            'main',
          );
        },
      );

      test(
        'should return an empty string when there is no default branch',
        () async {
          final d = await initTestDir();
          addTearDown(() => d.deleteSync(recursive: true));
          await initGit(d);
          await addAndCommitSampleFile(d);
          await git(d, ['branch', '-m', 'main', 'trunk']);

          expect(
            await defaultBranch.get(directory: d, ggLog: messages.add),
            '',
          );
        },
      );
    });

    group('exec(directory, ggLog)', () {
      test('should print the default branch', () async {
        await runner.run(['default-branch', '-i', local.path]);
        expect(messages.last, 'main');
      });
    });
  });
}
