// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_git/src/commands/is_pushed.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart' as h;

void main() {
  late Directory dRemote;
  late Directory dLocal;
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsPushed isPushed;
  late File file;

  // ...........................................................................
  Future<void> addRemoteToLocal() =>
      h.addRemoteToLocal(local: dLocal, remote: dRemote);

  // ...........................................................................
  void createFile() {
    file = File('${dLocal.path}/file.txt');
    file.writeAsStringSync('uncommitted');
  }

  // ...........................................................................
  void addFile() {
    final result = Process.runSync(
      'git',
      ['add', basename(file.path)],
      workingDirectory: dLocal.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not add file to local git repository.');
    }
  }

  // ...........................................................................
  void commitFile() {
    final result = Process.runSync(
      'git',
      ['commit', '-m', 'Initial commit'],
      workingDirectory: dLocal.path,
    );
    if (result.exitCode != 0) {
      throw Exception(
        'Could not commit file to local git repository. ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  void pushFile() {
    final result = Process.runSync(
      'git',
      ['push', '-u', 'origin', 'main'],
      workingDirectory: dLocal.path,
    );
    if (result.exitCode != 0) {
      throw Exception(
        'Could not push file to remote git repository. ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  void pull() {
    final result = Process.runSync(
      'git',
      ['pull'],
      workingDirectory: dLocal.path,
    );
    if (result.exitCode != 0) {
      throw Exception(
        'Could not pull to remote git repository. ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  void removeLastCommit() {
    final result = Process.runSync(
      'git',
      ['reset', '--hard', 'HEAD~1'],
      workingDirectory: dLocal.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could remove last commit. ${result.stderr}');
    }
  }

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    isPushed = IsPushed(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(isPushed);
  }

  // ...........................................................................
  Future<void> expectException(String message) async {
    await expectLater(
      runner.run(['is-pushed', '--input', dLocal.path]),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains(message),
        ),
      ),
    );
  }

  // ...........................................................................
  setUp(() async {
    dLocal = await initTestDir();
    dRemote = await initTestDir();

    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  // ...........................................................................
  tearDown(() {
    dLocal.deleteSync(recursive: true);
    dRemote.deleteSync(recursive: true);
  });

  group('IsPushed', () {
    // #########################################################################
    group('run(), get()', () {
      // #######################################################################
      group('should throw', () {
        // .....................................................................
        group('if "git status" fails', () {
          group('with inputDir', () {
            test('taken from --input arg', () async {
              final failingProcessWrapper = MockGgProcessWrapper();
              await initLocalGit(dLocal);
              initCommand(processWrapper: failingProcessWrapper);

              when(
                () => failingProcessWrapper.run(
                  any(),
                  any(),
                  workingDirectory: dLocal.path,
                ),
              ).thenAnswer(
                (_) async => ProcessResult(
                  1,
                  1,
                  'git status failed',
                  'git status failed',
                ),
              );

              await expectLater(
                runner.run(['is-pushed', '--input', dLocal.path]),
                throwsA(
                  isA<Exception>().having(
                    (e) => e.toString(),
                    'message',
                    'Exception: Could not run "git push" in "test".',
                  ),
                ),
              );
            });

            test('taken from constructor', () async {
              final failingProcessWrapper = MockGgProcessWrapper();
              await initLocalGit(dLocal);
              initCommand(
                processWrapper: failingProcessWrapper,
              );

              when(
                () => failingProcessWrapper.run(
                  any(),
                  any(),
                  workingDirectory: dLocal.path,
                ),
              ).thenAnswer(
                (_) async => ProcessResult(
                  1,
                  1,
                  'git status failed',
                  'git status failed',
                ),
              );

              when(
                () => failingProcessWrapper.run(
                  any(),
                  any(),
                  workingDirectory: dLocal.path,
                ),
              ).thenAnswer(
                (_) async => ProcessResult(
                  1,
                  1,
                  'git status failed',
                  'git status failed',
                ),
              );

              expect(
                () => isPushed.get(directory: dLocal, ggLog: messages.add),
                throwsA(
                  isA<Exception>().having(
                    (e) => e.toString(),
                    'message',
                    'Exception: Could not run "git push" in "test".',
                  ),
                ),
              );
            });
          });
        });

        // .....................................................................
        test('if "git returns an unknown status"', () async {
          final failingProcessWrapper = MockGgProcessWrapper();
          await initLocalGit(dLocal);
          initCommand(processWrapper: failingProcessWrapper);

          when(
            () => failingProcessWrapper.run(
              any(),
              any(),
              workingDirectory: dLocal.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(
              1,
              0,
              'Some unknown state',
              'Some unknown state',
            ),
          );

          await expectLater(
            runner.run(['is-pushed', '--input', dLocal.path]),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Unknown status of "git push" in "test".',
              ),
            ),
          );
        });

        // .....................................................................
        test('if not everything is pushed', () async {
          await initLocalGit(dLocal);
          initCommand();

          // Not yet added file?
          createFile();
          await expectException('There are untracked files.');

          // Not yet committed file?
          addFile();
          await expectException('There are staged but uncommitted changes.');

          // Not yet pushed file?
          commitFile();
          await expectException('The branch has no remote.');

          // Add a remote
          await initRemoteGit(dRemote);
          await addRemoteToLocal();

          // Push state
          await runner.run(['is-pushed', '--input', dLocal.path]);
          expect(messages.last, contains('✅ Everything is pushed.'));

          // .............
          // Make a change
          await file.writeAsString('is-committed');
          await expectException('There are not-added files.');

          // Not yet committed file?
          addFile();
          await expectException('There are staged but uncommitted changes.');

          // Not yet pushed file?
          commitFile();
          await expectException('The local branch is ahead of remote branch.');

          // Push state
          pushFile();
          await runner.run(['is-pushed', '--input', dLocal.path]);
          expect(messages.last, contains('Everything is pushed.'));

          // ..................
          // Remove last commit
          removeLastCommit();
          await expectException('Local branch is behind remote branch.');

          pull();
          await runner.run(['is-pushed', '--input', dLocal.path]);
          expect(messages.last, contains('Everything is pushed.'));
        });
      });

      group('should return true', () {
        test('when everything is committed and the state is pushed', () async {
          await initLocalGit(dLocal);
          await initRemoteGit(dRemote);
          initCommand();
          await addAndCommitSampleFile(dLocal, fileName: 'test.txt');
          await addRemoteToLocal();

          // Make a change without pushing
          await updateAndCommitSampleFile(dLocal, fileName: 'test.txt');

          expect(
            await isPushed.get(directory: dLocal, ggLog: messages.add),
            isFalse,
          );

          // Push the change
          pushFile();

          expect(
            await isPushed.get(directory: dLocal, ggLog: messages.add),
            isTrue,
          );
        });

        group('when not everything is committed and the state is pushed', () {
          test('but ignoreUnCommittedChanges is true', () async {
            await initLocalGit(dLocal);
            await initRemoteGit(dRemote);
            initCommand();
            await addAndCommitSampleFile(dLocal, fileName: 'test.txt');
            await addRemoteToLocal();

            // Push the change
            pushFile();

            // Make a change without committing
            File('${dLocal.path}/test.txt').writeAsStringSync('uncommitted');

            // Ask if it is pushed with ignoreUnCommittedChanges = true
            expect(
              await isPushed.get(
                directory: dLocal,
                ggLog: messages.add,
                ignoreUnCommittedChanges: true,
              ),
              isTrue,
            );
          });
        });
      });
    });

    group('should print »Everything is pushed.«', () {
      // .....................................................................
      test('when everything is pushed', () async {
        await initLocalGit(dLocal);
        initCommand();

        // Create a pushed file
        createFile();
        addFile();
        commitFile();

        // Add a remote
        await initRemoteGit(dRemote);
        await addRemoteToLocal();

        // Push state
        pushFile();
        await runner.run(['is-pushed', '--input', dLocal.path]);
        expect(messages.last, contains('Everything is pushed.'));

        // .............
        // Make a change
        await file.writeAsString('is-committed');
        addFile();
        commitFile();
        pushFile();
        await runner.run(['is-pushed', '--input', dLocal.path]);
        expect(messages.last, contains('Everything is pushed.'));

        // ..................
        // Remove last commit
        removeLastCommit();
        pull();
        await runner.run(['is-pushed', '--input', dLocal.path]);
        expect(messages.last, contains('Everything is pushed.'));
      });
    });
  });
}
