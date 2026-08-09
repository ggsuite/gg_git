// @license
// Copyright (c) 2019 - 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;

  setUp(() async {
    d = await initTestDir();
    await initGit(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  Future<void> commitOnMain(String message) async {
    await updateSampleFileWithoutCommitting(d);
    await commitFile(d, sampleFileName, message: message);
  }

  group('expectNoGgCommitsOnMain(repo)', () {
    test('passes for a main branch without gg commits', () async {
      await commitOnMain('Initial work');
      await commitOnMain('Release: publish gg_git');

      await expectNoGgCommitsOnMain(d);
    });

    test('throws when main carries a gg commit', () async {
      await commitOnMain('Initial work');
      await commitOnMain('#gg: Merged CDM-1 into main');

      await expectLater(
        expectNoGgCommitsOnMain(d),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('#gg: Merged CDM-1 into main'),
          ),
        ),
      );
    });

    test('throws for a legacy gg subject as well', () async {
      await commitOnMain('gg_multi: changed references to path');

      await expectLater(expectNoGgCommitsOnMain(d), throwsA(isA<Exception>()));
    });

    test('ignores commits before »since«', () async {
      await commitOnMain('#gg: old sin from before the rule');
      final ok = await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: d.path);
      final since = ok.stdout.toString().trim();
      await commitOnMain('Clean work after the rule');

      await expectNoGgCommitsOnMain(d, since: since);
    });

    test('accepts an explicit branch', () async {
      await commitOnMain('Initial work');
      await createBranch(d, 'CDM-1');
      await commitOnMain('#gg: bookkeeping on the feature branch');

      // The feature branch may carry gg commits ...
      await expectLater(
        expectNoGgCommitsOnMain(d, branch: 'CDM-1'),
        throwsA(isA<Exception>()),
      );

      // ... main not, and it is still clean.
      await expectNoGgCommitsOnMain(d);
    });

    test('throws when the history cannot be read', () async {
      final empty = await initTestDir();
      await Process.run('git', [
        'init',
        '--initial-branch=main',
      ], workingDirectory: empty.path);

      await expectLater(
        // The branch exists in name only — no commit, git log fails.
        expectNoGgCommitsOnMain(empty, branch: 'main'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not read the history'),
          ),
        ),
      );
    });

    test('throws when neither main nor master exists', () async {
      final empty = await initTestDir();
      await Process.run('git', [
        'init',
        '--initial-branch=trunk',
      ], workingDirectory: empty.path);

      await expectLater(
        expectNoGgCommitsOnMain(empty),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Neither »main« nor »master«'),
          ),
        ),
      );
    });
  });
}
