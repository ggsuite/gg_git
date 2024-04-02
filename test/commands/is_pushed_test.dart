// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/is_pushed.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart' as h;

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsPushed ggIsPushed;
  late Directory d;
  late Directory remoteDir;
  late Directory localDir;
  late File file;

  // ...........................................................................
  Future<void> initTestDir() async => d = await h.initTestDir();
  Future<void> initRemoteGit() async => remoteDir = await h.initRemoteGit(d);
  Future<void> initLocalGit() async => localDir = await h.initLocalGit(d);

  // ...........................................................................
  Future<void> addRemoteToLocal() =>
      h.addRemoteToLocal(local: localDir, remote: remoteDir);

  // ...........................................................................
  void createFile() {
    file = File('${localDir.path}/file.txt');
    file.writeAsStringSync('uncommitted');
  }

  // ...........................................................................
  void addFile() {
    final result = Process.runSync(
      'git',
      ['add', basename(file.path)],
      workingDirectory: localDir.path,
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
      workingDirectory: localDir.path,
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
      workingDirectory: localDir.path,
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
      workingDirectory: localDir.path,
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
      workingDirectory: localDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could remove last commit. ${result.stderr}');
    }
  }

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    ggIsPushed = IsPushed(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(ggIsPushed);
  }

  // ...........................................................................
  Future<void> expectException(String message) async {
    await expectLater(
      runner.run(['is-pushed', '--input', localDir.path]),
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
  setUp(() {
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  // ...........................................................................
  tearDown(() {});

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

              await initTestDir();
              await initLocalGit();
              initCommand(processWrapper: failingProcessWrapper);

              when(
                () => failingProcessWrapper.run(
                  any(),
                  any(),
                  workingDirectory: localDir.path,
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
                runner.run(['is-pushed', '--input', localDir.path]),
                throwsA(
                  isA<Exception>().having(
                    (e) => e.toString(),
                    'message',
                    'Exception: Could not run "git push" in "local".',
                  ),
                ),
              );
            });

            test('taken from constructor', () async {
              final failingProcessWrapper = MockGgProcessWrapper();

              await initTestDir();
              await initLocalGit();
              initCommand(
                processWrapper: failingProcessWrapper,
              );

              when(
                () => failingProcessWrapper.run(
                  any(),
                  any(),
                  workingDirectory: localDir.path,
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
                  workingDirectory: localDir.path,
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
                () => ggIsPushed.get(directory: localDir, ggLog: messages.add),
                throwsA(
                  isA<Exception>().having(
                    (e) => e.toString(),
                    'message',
                    'Exception: Could not run "git push" in "local".',
                  ),
                ),
              );
            });
          });
        });

        // .....................................................................
        test('if "git returns an unknown status"', () async {
          final failingProcessWrapper = MockGgProcessWrapper();

          await initTestDir();
          await initLocalGit();
          initCommand(processWrapper: failingProcessWrapper);

          when(
            () => failingProcessWrapper.run(
              any(),
              any(),
              workingDirectory: localDir.path,
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
            runner.run(['is-pushed', '--input', localDir.path]),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Unknown status of "git push" in "local".',
              ),
            ),
          );
        });

        // .....................................................................
        test('if not everything is pushed', () async {
          await initTestDir();
          await initLocalGit();
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
          await initRemoteGit();
          await addRemoteToLocal();

          // Push state
          await runner.run(['is-pushed', '--input', localDir.path]);
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
          await runner.run(['is-pushed', '--input', localDir.path]);
          expect(messages.last, contains('Everything is pushed.'));

          // ..................
          // Remove last commit
          removeLastCommit();
          await expectException('Local branch is behind remote branch.');

          pull();
          await runner.run(['is-pushed', '--input', localDir.path]);
          expect(messages.last, contains('Everything is pushed.'));
        });
      });
    });

    group('should print »Everything is pushed.«', () {
      // .....................................................................
      test('when everything is pushed', () async {
        await initTestDir();
        await initLocalGit();
        initCommand();

        // Create a pushed file
        createFile();
        addFile();
        commitFile();

        // Add a remote
        await initRemoteGit();
        await addRemoteToLocal();

        // Push state
        pushFile();
        await runner.run(['is-pushed', '--input', localDir.path]);
        expect(messages.last, contains('Everything is pushed.'));

        // .............
        // Make a change
        await file.writeAsString('is-committed');
        addFile();
        commitFile();
        pushFile();
        await runner.run(['is-pushed', '--input', localDir.path]);
        expect(messages.last, contains('Everything is pushed.'));

        // ..................
        // Remove last commit
        removeLastCommit();
        pull();
        await runner.run(['is-pushed', '--input', localDir.path]);
        expect(messages.last, contains('Everything is pushed.'));
      });
    });
  });
}
