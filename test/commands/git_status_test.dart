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
  late GitStatus gitStatus;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);
    gitStatus = GitStatus(ggLog: messages.add);
  });

  group('parseGitStatus(stdout)', () {
    test('reads the two status columns positionally', () {
      // » M file« — the leading space is meaningful and must survive.
      final entries = parseGitStatus(' M lib/a.dart\nM  lib/b.dart\n');
      expect(entries, hasLength(2));
      expect(entries[0].x, ' ');
      expect(entries[0].y, 'M');
      expect(entries[0].path, 'lib/a.dart');
      expect(entries[1].x, 'M');
      expect(entries[1].y, ' ');
      expect(entries[1].path, 'lib/b.dart');
    });

    test('returns both names of a rename', () {
      final entries = parseGitStatus('R  old.dart -> new.dart\n');
      expect(entries.single.path, 'new.dart');
      expect(entries.single.renamedFrom, 'old.dart');
      expect(entries.single.paths, ['new.dart', 'old.dart']);
    });

    test('treats a copy like a rename', () {
      final entries = parseGitStatus('C  src.dart -> copy.dart\n');
      expect(entries.single.renamedFrom, 'src.dart');
      expect(entries.single.paths, ['copy.dart', 'src.dart']);
    });

    test('does not split an arrow inside a plain file name', () {
      final entries = parseGitStatus(' M weird -> name.dart\n');
      expect(entries.single.path, 'weird -> name.dart');
      expect(entries.single.renamedFrom, isNull);
      expect(entries.single.paths, ['weird -> name.dart']);
    });

    test('recognizes untracked, ignored and unmerged entries', () {
      final entries = parseGitStatus(
        '?? new.dart\n'
        '!! build/out\n'
        'UU conflict.dart\n'
        'AA both-added.dart\n'
        'DD both-deleted.dart\n',
      );
      expect(entries[0].isUntracked, isTrue);
      expect(entries[1].isIgnored, isTrue);
      expect(entries[2].isUnmerged, isTrue);
      expect(entries[3].isUnmerged, isTrue);
      expect(entries[4].isUnmerged, isTrue);
      expect(entries[0].isUnmerged, isFalse);
    });

    test('skips empty and truncated lines', () {
      expect(parseGitStatus(''), isEmpty);
      expect(parseGitStatus('\n\n'), isEmpty);
      expect(parseGitStatus('M\n'), isEmpty);
      expect(parseGitStatus('M  \n'), isEmpty);
    });

    test('strips a trailing carriage return', () {
      final entries = parseGitStatus(' M lib/a.dart\r\n');
      expect(entries.single.path, 'lib/a.dart');
    });

    test('toString names the columns and both paths', () {
      expect(parseGitStatus(' M a.dart\n').single.toString(), ' M a.dart');
      expect(
        parseGitStatus('R  a.dart -> b.dart\n').single.toString(),
        'R  b.dart <- a.dart',
      );
    });
  });

  group('GitStatus', () {
    group('get(directory)', () {
      test('returns an empty list for a clean repository', () async {
        expect(await gitStatus.get(directory: d, ggLog: messages.add), isEmpty);
      });

      test('lists untracked files individually, not as a folder', () async {
        // The porcelain default collapses this into »?? sub/«, which cannot
        // be turned into a pathspec — --untracked-files=all prevents that.
        await Directory('${d.path}/sub').create();
        await File('${d.path}/sub/a.txt').writeAsString('a');
        await File('${d.path}/sub/b.txt').writeAsString('b');

        final entries = await gitStatus.get(directory: d, ggLog: messages.add);
        expect(
          entries.map((e) => e.path),
          containsAll(<String>['sub/a.txt', 'sub/b.txt']),
        );
        expect(entries.every((e) => e.isUntracked), isTrue);
      });

      test('reports a modified tracked file', () async {
        await addAndCommitSampleFile(d, fileName: 'a.txt', content: 'one');
        await File('${d.path}/a.txt').writeAsString('two');

        final entries = await gitStatus.get(directory: d, ggLog: messages.add);
        expect(entries.single.path, 'a.txt');
        expect(entries.single.y, 'M');
      });

      test('omits untracked files when includeUntracked is false', () async {
        await addAndCommitSampleFile(d, fileName: 'a.txt', content: 'one');
        await File('${d.path}/a.txt').writeAsString('two');
        await File('${d.path}/untracked.txt').writeAsString('x');

        final entries = await gitStatus.get(
          directory: d,
          ggLog: messages.add,
          includeUntracked: false,
        );
        expect(entries.map((e) => e.path), ['a.txt']);
      });

      test('throws when the directory is no git repository', () async {
        final noRepo = await initTestDir();
        await expectLater(
          gitStatus.get(directory: noRepo, ggLog: messages.add),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws when git status itself fails', () async {
        final processWrapper = MockGgProcessWrapper();
        when(
          () => processWrapper.run('git', any(), workingDirectory: d.path),
        ).thenAnswer((_) async => ProcessResult(1, 1, '', 'git is unhappy'));

        final failing = GitStatus(
          ggLog: messages.add,
          processWrapper: processWrapper,
        );

        await expectLater(
          failing.get(directory: d, ggLog: messages.add),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Could not read the git status: git is unhappy'),
            ),
          ),
        );
      });
    });

    group('exec(directory)', () {
      test('logs one line per entry', () async {
        await File('${d.path}/a.txt').writeAsString('a');

        final result = await gitStatus.exec(directory: d, ggLog: messages.add);

        expect(result.single.path, 'a.txt');
        expect(messages.last, contains('a.txt'));
      });
    });
  });
}
