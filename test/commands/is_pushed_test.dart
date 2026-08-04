// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart' as h;

void main() {
  registerFallbackValue(MockUpstreamBranch());
  registerFallbackValue(Directory.systemTemp);

  late Directory dRemote;
  late Directory dLocal;
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsPushed isPushed;
  late File file;

  // ...........................................................................
  void createFile() {
    file = File('${dLocal.path}/file.txt');
    file.writeAsStringSync('uncommitted');
  }

  // ...........................................................................
  void addFile() {
    final result = Process.runSync('git', [
      'add',
      basename(file.path),
    ], workingDirectory: dLocal.path);
    if (result.exitCode != 0) {
      throw Exception('Could not add file to local git repository.');
    }
  }

  // ...........................................................................
  void commitFile() {
    final result = Process.runSync('git', [
      'commit',
      '-m',
      'Initial commit',
    ], workingDirectory: dLocal.path);
    if (result.exitCode != 0) {
      throw Exception(
        'Could not commit file to local git repository. ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  void pushFile() {
    final result = Process.runSync('git', [
      'push',
      '-u',
      'origin',
      'main',
    ], workingDirectory: dLocal.path);
    if (result.exitCode != 0) {
      throw Exception(
        'Could not push file to remote git repository. ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  void pull() {
    final result = Process.runSync('git', [
      'pull',
    ], workingDirectory: dLocal.path);
    if (result.exitCode != 0) {
      throw Exception(
        'Could not pull to remote git repository. ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  void removeLastCommit() {
    final result = Process.runSync('git', [
      'reset',
      '--hard',
      'HEAD~1',
    ], workingDirectory: dLocal.path);
    if (result.exitCode != 0) {
      throw Exception('Could remove last commit. ${result.stderr}');
    }
  }

  // ...........................................................................
  void initCommand({
    GgProcessWrapper? processWrapper,
    MockUpstreamBranch? upstreamBranch,
  }) {
    isPushed = IsPushed(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
      upstreamBranch: upstreamBranch,
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
        late MockUpstreamBranch upstreamBranch;

        setUpAll(() {
          upstreamBranch = MockUpstreamBranch();

          // Mock an given upstream branch
          when(
            () => upstreamBranch.get(
              ggLog: any(named: 'ggLog'),
              directory: any(named: 'directory'),
            ),
          ).thenAnswer((_) async => 'origin/main');
        });

        // .....................................................................
        group('if "git status" fails', () {
          group('with inputDir', () {
            test('taken from --input arg', () async {
              final failingProcessWrapper = MockGgProcessWrapper();
              await initLocalGit(dLocal);

              initCommand(
                processWrapper: failingProcessWrapper,
                upstreamBranch: upstreamBranch,
              );

              // Mock a failing git status
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
                upstreamBranch: upstreamBranch,
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
        test('if not everything is pushed', () async {
          await initLocalGit(dLocal);
          initCommand(upstreamBranch: upstreamBranch);

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
          await h.addRemoteToLocal(local: dLocal, remote: dRemote);

          // Push state
          await runner.run(['is-pushed', '--input', dLocal.path]);
          expect(
            rmControls(messages.last),
            contains('✓ Everything is pushed.'),
          );

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
          await addRemoteToLocal(local: dLocal, remote: dRemote);

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
            await addRemoteToLocal(local: dLocal, remote: dRemote);

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

      group('should return false', () {
        test('if local git has no remote', () async {
          // Make sure the branch has no upstream branch
          await initLocalGit(dLocal);
          expect(await upstreamBranchName(dLocal), isEmpty);

          // IsPushed should return false
          initCommand();
          expect(
            await isPushed.get(directory: dLocal, ggLog: messages.add),
            isFalse,
          );
        });

        test('if the branch has no upstream branch', () async {
          initCommand();

          // No remote
          await initLocalGit(dLocal);
          expect(await upstreamBranchName(dLocal), isEmpty);

          // Remote with main branch
          await initRemoteGit(dRemote);
          await addRemoteToLocal(local: dLocal, remote: dRemote);
          expect(await upstreamBranchName(dLocal), 'origin/main');

          // Feature branch without upstream
          await createBranch(dLocal, 'feature');
          expect(await upstreamBranchName(dLocal), isEmpty);

          // => isPushed should return false
          expect(
            await isPushed.get(directory: dLocal, ggLog: messages.add),
            isFalse,
          );
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
        await addRemoteToLocal(local: dLocal, remote: dRemote);

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

    // #########################################################################
    group('should evaluate »git status --porcelain=v2 --branch«', () {
      late MockUpstreamBranch upstreamBranch;

      // .......................................................................
      /// Answers »git status« with [stdout] and returns the result of get().
      Future<bool> statusIs(String stdout, {bool ignore = false}) async {
        final processWrapper = MockGgProcessWrapper();
        when(
          () => processWrapper.run('git', [
            'status',
            '--porcelain=v2',
            '--branch',
          ], workingDirectory: dLocal.path),
        ).thenAnswer((_) async => ProcessResult(1, 0, stdout, ''));

        final isPushed = IsPushed(
          ggLog: messages.add,
          processWrapper: processWrapper,
          upstreamBranch: upstreamBranch,
        );

        return isPushed.get(
          directory: dLocal,
          ggLog: messages.add,
          ignoreUnCommittedChanges: ignore,
        );
      }

      // .......................................................................
      const header =
          '# branch.oid abc123\n'
          '# branch.head main\n'
          '# branch.upstream origin/main\n';

      setUp(() {
        upstreamBranch = MockUpstreamBranch();
        when(
          () => upstreamBranch.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => 'origin/main');
      });

      test('and not depend on the language of the git output', () async {
        // The German »git status« prose would not match any English literal.
        expect(await statusIs('$header# branch.ab +0 -0\n'), isTrue);
        expect(messages.last, contains('Everything is pushed.'));
      });

      test('and report ahead and behind commits', () async {
        expect(await statusIs('$header# branch.ab +2 -0\n'), isFalse);
        expect(
          messages.last,
          contains('The local branch is ahead of remote branch.'),
        );

        expect(await statusIs('$header# branch.ab +0 -3\n'), isFalse);
        expect(
          messages.last,
          contains('Local branch is behind remote branch.'),
        );
      });

      test('and report untracked files', () async {
        const status = '$header# branch.ab +0 -0\n? untracked.txt\n';
        expect(await statusIs(status), isFalse);
        expect(messages.last, contains('There are untracked files.'));
        expect(await statusIs(status, ignore: true), isTrue);
      });

      test('and report staged changes', () async {
        const status =
            '$header# branch.ab +0 -0\n'
            '1 M. N... 100644 100644 100644 abc abc staged.txt\n';
        expect(await statusIs(status), isFalse);
        expect(
          messages.last,
          contains('There are staged but uncommitted changes.'),
        );
        expect(await statusIs(status, ignore: true), isTrue);
      });

      test('and report unstaged changes', () async {
        const status =
            '$header# branch.ab +0 -0\n'
            '1 .M N... 100644 100644 100644 abc abc unstaged.txt\n';
        expect(await statusIs(status), isFalse);
        expect(messages.last, contains('There are not-added files.'));
      });

      test('and report renamed files', () async {
        const status =
            '$header# branch.ab +0 -0\n'
            '2 R. N... 100644 100644 100644 abc abc '
            'R100 new.txt\told.txt\n';
        expect(await statusIs(status), isFalse);
        expect(
          messages.last,
          contains('There are staged but uncommitted changes.'),
        );
      });

      test('and report unmerged files', () async {
        const status =
            '$header# branch.ab +0 -0\n'
            'u UU N... 100644 100644 100644 100644 a b c conflict.txt\n';
        expect(await statusIs(status), isFalse);
        expect(messages.last, contains('There are not-added files.'));
      });

      test('and report a missing »# branch.ab« as »no remote«', () async {
        expect(await statusIs(header), isFalse);
        expect(messages.last, contains('The branch has no remote.'));
      });
    });
  });
}
