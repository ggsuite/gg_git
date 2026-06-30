// @license
// Copyright (c) 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  final messages = <String>[];
  late MockGgProcessWrapper processWrapper;
  late RemoteBranchExists remoteBranchExists;

  final args = ['rev-parse', '--verify', '--quiet', 'refs/remotes/origin/feat'];

  setUp(() async {
    d = await initTestDir();
    messages.clear();
    processWrapper = MockGgProcessWrapper();
    remoteBranchExists = RemoteBranchExists(
      ggLog: messages.add,
      processWrapper: processWrapper,
    );
  });

  tearDown(() => d.deleteSync(recursive: true));

  group('RemoteBranchExists', () {
    test('throws when no branch is given', () async {
      expect(
        () => remoteBranchExists.get(directory: d, ggLog: messages.add),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns true when the ref resolves', () async {
      when(
        () => processWrapper.run('git', args, workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, 'hash', ''));

      final exists = await remoteBranchExists.get(
        directory: d,
        ggLog: messages.add,
        branch: 'feat',
      );
      expect(exists, isTrue);
    });

    test('returns false when the ref is missing', () async {
      when(
        () => processWrapper.run('git', args, workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 1, '', ''));

      final exists = await remoteBranchExists.get(
        directory: d,
        ggLog: messages.add,
        branch: 'feat',
      );
      expect(exists, isFalse);
    });

    test('exec delegates to get', () async {
      when(
        () => processWrapper.run('git', args, workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, 'hash', ''));

      final exists = await remoteBranchExists.exec(
        directory: d,
        ggLog: messages.add,
        branch: 'feat',
      );
      expect(exists, isTrue);
    });

    test('reads the branch from the positional CLI argument', () async {
      when(
        () => processWrapper.run(
          'git',
          args,
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).thenAnswer((_) async => ProcessResult(1, 0, 'hash', ''));

      final runner = CommandRunner<void>('gg', 'gg')
        ..addCommand(remoteBranchExists);
      await runner.run(['remote-branch-exists', '-i', d.path, 'feat']);

      verify(
        () => processWrapper.run(
          'git',
          args,
          workingDirectory: any(named: 'workingDirectory'),
        ),
      ).called(1);
    });
  });
}
