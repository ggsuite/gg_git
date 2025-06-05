// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
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
  late Directory dLocal;
  late Directory dRemote;

  final messages = <String>[];
  late CommandRunner<void> runner;
  late HasRemote hasRemote;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    hasRemote = HasRemote(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(hasRemote);
  }

  // ...........................................................................
  setUp(() async {
    dLocal = await initTestDir();
    dRemote = await initTestDir();
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  tearDown(() {
    dLocal.deleteSync(recursive: true);
    dRemote.deleteSync(recursive: true);
  });

  group('HasRemote', () {
    // #########################################################################
    group('get()', () {
      test('should throw if "git remote" fails', () async {
        await initGit(dLocal);
        final failingProcessWrapper = MockGgProcessWrapper();

        initCommand(processWrapper: failingProcessWrapper);

        when(
          () => failingProcessWrapper.run('git', [
            'remote',
          ], workingDirectory: dLocal.path),
        ).thenAnswer(
          (_) async =>
              ProcessResult(1, 1, 'git remote failed', 'git remote failed'),
        );

        late String exception;

        try {
          await hasRemote.get(directory: dLocal, ggLog: messages.add);
        } catch (e) {
          exception = e.toString();
        }

        expect(
          exception,
          'Exception: Could not run "git remote" in "test": '
          'git remote failed',
        );
      });

      // .......................................................................
      group('should return', () {
        group('false', () {
          test('when repo has no remote', () async {
            await initGit(dLocal);
            initCommand();

            final result = await hasRemote.get(
              directory: dLocal,
              ggLog: messages.add,
            );

            expect(result, isFalse);
          });
        });

        // .....................................................................
        group('true', () {
          test('when repo has a remote', () async {
            await initGit(dLocal);
            await addAndCommitSampleFile(dLocal);

            initCommand();
            await initRemoteGit(dRemote);
            await addRemoteToLocal(local: dLocal, remote: dRemote);

            final result = await hasRemote.get(
              directory: dLocal,
              ggLog: messages.add,
            );

            expect(result, isTrue);
          });
        });
      });
    });

    group('exec(directory, ggLog)', () {
      group('should print ❌ and throw', () {
        test('when repo has no remote', () async {
          await initGit(dLocal);
          initCommand();

          late String exception;

          try {
            await runner.run(['has-remote', '-i', dLocal.path]);
          } catch (e) {
            exception = e.toString();
          }

          expect(messages[0], contains('⌛️ Has a remote.'));
          expect(messages[1], contains('❌ Has a remote.'));

          expect(exception, contains('Repo has no remote.'));
        });
      });

      group('should print ✅ when repo has a remote', () {
        test('when repo has a remote', () async {
          await initGit(dLocal);
          await addAndCommitSampleFile(dLocal);

          initCommand();
          await initRemoteGit(dRemote);
          await addRemoteToLocal(local: dLocal, remote: dRemote);

          await runner.run(['has-remote', '-i', dLocal.path]);

          expect(messages[0], contains('⌛️ Has a remote.'));
          expect(messages[1], contains('✅ Has a remote.'));
        });
      });
    });
  });
}
