// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  final messages = <String>[];
  late MockGgProcessWrapper processWrapper;
  late RemoteBranches remoteBranches;

  final args = ['for-each-ref', '--format=%(refname)', 'refs/remotes/origin'];

  setUp(() async {
    d = await initTestDir();
    messages.clear();
    processWrapper = MockGgProcessWrapper();
    remoteBranches = RemoteBranches(
      ggLog: messages.add,
      processWrapper: processWrapper,
    );
  });

  tearDown(() => d.deleteSync(recursive: true));

  group('RemoteBranches', () {
    test('drops HEAD, strips origin/ and keeps main/master', () async {
      when(() => processWrapper.run('git', args, workingDirectory: d.path))
          .thenAnswer(
            (_) async => ProcessResult(
              1,
              0,
              'refs/remotes/origin/HEAD\nrefs/remotes/origin/main\n'
                  'refs/remotes/origin/master\n\nrefs/remotes/origin/feat_a\n'
                  'refs/remotes/origin/feat_b\n',
              '',
            ),
          );

      final branches = await remoteBranches.get(
        directory: d,
        ggLog: messages.add,
      );
      expect(branches, ['main', 'master', 'feat_a', 'feat_b']);
    });

    // Regression: with `%(refname:short)` git printed the symbolic
    // `refs/remotes/origin/HEAD` as plain `origin`, which slipped past the
    // `origin/HEAD` filter and was offered as a branch named »origin«.
    test('does not list origin/HEAD as a branch named origin', () async {
      final (local, remote) = await initLocalAndRemoteGit();
      addTearDown(() {
        local.deleteSync(recursive: true);
        remote.deleteSync(recursive: true);
      });
      await addAndCommitSampleFile(local);
      await pushLocalChangesUpstream(local, 'main');
      await createBranch(local, 'feat_x');
      await pushLocalChangesUpstream(local, 'feat_x');
      await Process.run('git', [
        'remote',
        'set-head',
        'origin',
        'main',
      ], workingDirectory: local.path);

      final branches = await RemoteBranches(ggLog: messages.add)
          .get(directory: local, ggLog: messages.add);
      expect(branches, unorderedEquals(['main', 'feat_x']));
    });

    test('throws when the listing fails', () async {
      when(() => processWrapper.run('git', args, workingDirectory: d.path))
          .thenAnswer((_) async => ProcessResult(1, 1, '', 'boom'));

      expect(
        () => remoteBranches.get(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not list remote branches in'),
          ),
        ),
      );
    });

    test('exec delegates to get', () async {
      when(() => processWrapper.run('git', args, workingDirectory: d.path))
          .thenAnswer(
            (_) async =>
                ProcessResult(1, 0, 'refs/remotes/origin/feat_a\n', ''),
          );

      final branches = await remoteBranches.exec(
        directory: d,
        ggLog: messages.add,
      );
      expect(branches, ['feat_a']);
    });
  });
}
