// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:test/test.dart';

void main() {
  /// A runner answering `git --version` with [stdout] and counting its calls.
  ({ProcessRunner runner, List<String> calls}) git(String stdout) {
    final calls = <String>[];
    Future<ProcessResult> runner(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool runInShell = true,
    }) async {
      calls.add([executable, ...arguments].join(' '));
      return ProcessResult(0, 0, stdout, '');
    }

    return (runner: runner, calls: calls);
  }

  setUp(GitVersion.reset);
  tearDown(GitVersion.reset);

  group('GitVersion', () {
    group('parse()', () {
      test('reads major and minor', () {
        expect(GitVersion.parse('git version 2.56.0.windows.4'), (2, 56));
        expect(GitVersion.parse('git version 2.39.5 (Apple Git-154)'), (2, 39));
        expect(GitVersion.parse('git version 3.0'), (3, 0));
      });

      test('gives 0.0 for an answer without a version', () {
        expect(GitVersion.parse(''), (0, 0));
        expect(GitVersion.parse('command not found'), (0, 0));
      });
    });

    group('isAtLeast()', () {
      test('compares with the installed git', () async {
        final version = GitVersion(
          processRunner: git('git version 2.48.1').runner,
        );

        expect(await version.isAtLeast(2, 48), isTrue);
        expect(await version.isAtLeast(2, 47), isTrue);
        expect(await version.isAtLeast(1, 99), isTrue);
        expect(await version.isAtLeast(2, 49), isFalse);
        expect(await version.isAtLeast(3, 0), isFalse);
      });

      test('asks git once per process', () async {
        final (:runner, :calls) = git('git version 2.56.0');

        await GitVersion(processRunner: runner).isAtLeast(2, 48);
        await GitVersion(processRunner: runner).isAtLeast(2, 0);

        expect(calls, ['git --version']);
      });

      test('asks again after reset()', () async {
        final (:runner, :calls) = git('git version 2.56.0');

        await GitVersion(processRunner: runner).isAtLeast(2, 48);
        GitVersion.reset();
        await GitVersion(processRunner: runner).isAtLeast(2, 48);

        expect(calls, hasLength(2));
      });

      test('takes a git that cannot be started as older than all', () async {
        Future<ProcessResult> missing(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = true,
        }) => throw const ProcessException('git', ['--version']);

        final version = GitVersion(processRunner: missing);
        expect(await version.isAtLeast(0, 1), isFalse);
      });

      test('asks the real git by default', () async {
        expect(await const GitVersion().isAtLeast(1, 0), isTrue);
      });
    });

    group('fixed()', () {
      test('is that version, without asking git', () async {
        const version = GitVersion.fixed(2, 40);
        expect(await version.isAtLeast(2, 40), isTrue);
        expect(await version.isAtLeast(2, 48), isFalse);
      });
    });

    group('unknown()', () {
      test('is older than every version', () async {
        expect(await const GitVersion.unknown().isAtLeast(0, 1), isFalse);
      });
    });

    test('knows the first git that follows the remote HEAD', () {
      expect(GitVersion.followRemoteHead, (2, 48));
    });
  });
}
