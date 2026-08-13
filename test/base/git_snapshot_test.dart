// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockProcessRunner extends Mock {
  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool? runInShell,
  });
}

void main() {
  late MockProcessRunner m;
  final repoDir = Directory('some/repo');

  setUp(() {
    m = MockProcessRunner();
  });

  group('runGit', () {
    test('returns the trimmed stdout on success', () async {
      when(
        () => m('git', [
          'status',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 0, '  out\n', ''));

      final out = await runGit(m.call, ['status'], repoDir: repoDir);
      expect(out, 'out');
    });

    test('returns an empty string when stdout is null', () async {
      when(
        () => m('git', [
          'status',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 0, null, ''));

      final out = await runGit(m.call, ['status'], repoDir: repoDir);
      expect(out, '');
    });

    test('throws with the stderr detail on a non-zero exit', () async {
      when(
        () => m('git', [
          'boom',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 1, '', ' the error '));

      await expectLater(
        () => runGit(m.call, ['boom'], repoDir: repoDir),
        throwsA(
          isA<Exception>().having(
            (e) => rmControls(e.toString()),
            'message',
            allOf(contains('git boom failed in repo'), contains('the error')),
          ),
        ),
      );
    });

    test('falls back to stdout for the detail when stderr is empty', () async {
      when(
        () => m('git', [
          'boom',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 1, 'stdout cause', ''));

      await expectLater(
        () => runGit(m.call, ['boom'], repoDir: repoDir),
        throwsA(
          isA<Exception>().having(
            (e) => rmControls(e.toString()),
            'message',
            contains('stdout cause'),
          ),
        ),
      );
    });

    test('tolerates a non-zero exit when allowFailure is set', () async {
      when(
        () => m('git', [
          'rebase',
          '--abort',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 1, 'nothing', 'no rebase'));

      final out = await runGit(
        m.call,
        ['rebase', '--abort'],
        repoDir: repoDir,
        allowFailure: true,
      );
      expect(out, 'nothing');
    });
  });

  group('captureUncommitted', () {
    test('returns null and runs nothing when the status is empty', () async {
      final sha = await captureUncommitted(
        m.call,
        repoDir: repoDir,
        status: '',
      );
      expect(sha, isNull);
      verifyNever(
        () => m('git', [
          'stash',
          'push',
          '--include-untracked',
          '--message',
          'gg-multi snapshot',
        ], workingDirectory: any(named: 'workingDirectory')),
      );
    });

    test('stashes, records the hash, re-applies and drops', () async {
      when(
        () => m('git', [
          'stash',
          'push',
          '--include-untracked',
          '--message',
          'gg-multi snapshot',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));
      when(
        () => m('git', [
          'rev-parse',
          'stash@{0}',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 0, 'thesha', ''));
      when(
        () => m('git', [
          'stash',
          'apply',
          '--index',
          'stash@{0}',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));
      when(
        () => m('git', [
          'stash',
          'drop',
          'stash@{0}',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

      final sha = await captureUncommitted(
        m.call,
        repoDir: repoDir,
        status: ' M lib/a.dart',
      );

      expect(sha, 'thesha');
      verify(
        () => m('git', [
          'stash',
          'push',
          '--include-untracked',
          '--message',
          'gg-multi snapshot',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).called(1);
      verify(
        () => m('git', [
          'stash',
          'drop',
          'stash@{0}',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).called(1);
    });
  });
}
