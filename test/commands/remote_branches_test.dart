// @license
// Copyright (c) 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
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

  final args = [
    'for-each-ref',
    '--format=%(refname:short)',
    'refs/remotes/origin',
  ];

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
      when(
        () => processWrapper.run('git', args, workingDirectory: d.path),
      ).thenAnswer(
        (_) async => ProcessResult(
          1,
          0,
          'origin/HEAD\norigin/main\norigin/master\n\norigin/feat_a\n'
              'origin/feat_b\n',
          '',
        ),
      );

      final branches = await remoteBranches.get(
        directory: d,
        ggLog: messages.add,
      );
      expect(branches, ['main', 'master', 'feat_a', 'feat_b']);
    });

    test('throws when the listing fails', () async {
      when(
        () => processWrapper.run('git', args, workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 1, '', 'boom'));

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
      when(
        () => processWrapper.run('git', args, workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, 'origin/feat_a\n', ''));

      final branches = await remoteBranches.exec(
        directory: d,
        ggLog: messages.add,
      );
      expect(branches, ['feat_a']);
    });
  });
}
