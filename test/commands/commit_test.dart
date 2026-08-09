// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late Directory dRemote;
  late Commit commit;
  late CommitCount commitCount;
  late HeadMessage headMessage;
  final messages = <String>[];
  const commitMessage = 'My commit message';

  setUp(() async {
    messages.clear();
    (d, dRemote) = await initLocalAndRemoteGit();
    commit = Commit(ggLog: messages.add);
    commitCount = CommitCount(ggLog: messages.add);
    headMessage = HeadMessage(ggLog: messages.add);
  });

  tearDown(() async {
    await d.delete(recursive: true);
    await dRemote.delete(recursive: true);
  });

  group('Commit', () {
    group('commit(directory, message, doStage, ammend)', () {
      group('should throw', () {
        test('if there is nothing to commit', () async {
          // At the beginning, there is nothing to commit
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: 'Initial commit',
              doStage: false,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Nothing to commit. No uncommmited changes.',
          );
        });

        test('if doStage == false and no staged files exist', () async {
          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Commit the file without staging before
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: false,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(exception, contains('use "git add" to track'));

          // Check the commit
        });

        test('if an error happens while staging', () async {
          // Mock staging fails
          final processWrapper = MockGgProcessWrapper();
          when(
            () => processWrapper.run('git', [
              'add',
              '.',
            ], workingDirectory: d.path),
          ).thenAnswer(
            (_) async => ProcessResult(1, 1, '', 'Some staging error'),
          );

          // Create an instance
          commit = Commit(ggLog: messages.add, processWrapper: processWrapper);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Stage the file
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: 'Initial commit',
              doStage: true,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Could not stage files: Some staging error',
          );
        });

        test('if an error happens while committing', () async {
          // Mock staging succeeds
          final processWrapper = MockGgProcessWrapper();
          when(
            () => processWrapper.run('git', [
              'add',
              '.',
            ], workingDirectory: d.path),
          ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

          // Mock committing fails
          when(
            () => processWrapper.run('git', [
              'commit',
              '-m',
              commitMessage,
            ], workingDirectory: d.path),
          ).thenAnswer(
            (_) async => ProcessResult(1, 1, '', 'My commit error.'),
          );

          // Create an instance
          commit = Commit(ggLog: messages.add, processWrapper: processWrapper);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Stage the file
          late String exception;

          try {
            await commit.commit(
              directory: d,
              message: commitMessage,
              doStage: true,
              ggLog: messages.add,
            );
          } catch (e) {
            exception = e.toString();
          }

          expect(
            exception,
            'Exception: Could not commit files: My commit error.',
          );
        });

        test(
          'if ammend and ammendWhenNotPushed is true at the same time',
          () async {
            // Let's modify a file
            await addFileWithoutCommitting(d, fileName: 'file1.txt');

            // Commit the file
            late String exception;

            try {
              await commit.commit(
                directory: d,
                message: commitMessage,
                doStage: true,
                ammend: true,
                ammendWhenNotPushed: true,
                ggLog: messages.add,
              );
            } catch (e) {
              exception = e.toString();
            }

            expect(
              exception,
              'Exception: You cannot use --ammend and --ammend-when-not-pushed '
              'at the same time.',
            );
          },
        );
      });

      group('should commit files', () {
        test('with doStage = true', () async {
          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');

          // Commit the file
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ggLog: messages.add,
          );

          // Check the commit
          final result = Process.runSync('git', [
            'log',
            '-1',
            '--pretty=%B',
          ], workingDirectory: d.path);

          expect(result.stdout.trim(), commitMessage);
        });

        test('with doStage = false', () async {
          // Let's modify two files
          await addFileWithoutCommitting(d, fileName: 'file1.txt');
          await addFileWithoutCommitting(d, fileName: 'file2.txt');

          // Let's stage only one file
          await stageFile(d, 'file1.txt');

          // Commit the file without additional staging
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: false,
            ggLog: messages.add,
          );

          // Only file1.txt should be committed
          expect(await modifiedFiles(d), ['file2.txt']);
        });
      });

      group('should ammend files', () {
        test('when ammend = true', () async {
          // Let's modify a file
          await addAndCommitSampleFile(d, fileName: 'file1.txt');

          // Count the number of commits
          final count0 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );

          // Modify the file again
          File('${d.path}/file1.txt').writeAsStringSync('Change 2!');

          // Commit the file again with ammend = false
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ammend: false,
            ggLog: messages.add,
          );

          // Commit count should have increased
          final count1 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );
          expect(count1, count0 + 1);

          // Make another change
          File('${d.path}/file1.txt').writeAsStringSync('Change 3!');

          // Commit the file again with ammend = true
          await commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ammend: true,
            ggLog: messages.add,
          );

          // Commit count should be the same
          final count2 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(count2, count1);
        });

        group(
          'when ammendWhenNotPushed is true and state is not yet pushed',
          () {
            test(
              'and it should not overwrite the last commit message',
              () async {
                // Let's modify a file
                await addAndCommitSampleFile(
                  d,
                  fileName: 'file1.txt',
                  message: 'Commit message 0',
                );

                // Count the number of commits
                final count0 = await commitCount.get(
                  ggLog: messages.add,
                  directory: d,
                );

                // Modify the file again
                File('${d.path}/file1.txt').writeAsStringSync('Change 2!');

                // Commit the file again with ammendWhenNotPushed = true
                await commit.commit(
                  directory: d,
                  message: 'Commit message 1',
                  doStage: true,
                  ammendWhenNotPushed: true,
                  ggLog: messages.add,
                );

                // Commit count should not have increased
                // because we did not push yet.
                final count1 = await commitCount.get(
                  ggLog: messages.add,
                  directory: d,
                );
                expect(count1, count0);

                // Commit message should be the previous one.
                // because the commit was ammended
                final commitMessage1 = await headMessage.get(
                  ggLog: messages.add,
                  directory: d,
                );
                expect(commitMessage1, 'Commit message 0');

                // Push the current state
                await pushLocalChanges(d);

                // Make another change
                File('${d.path}/file1.txt').writeAsStringSync('Change 3!');

                // Commit the file again with ammendWhenNotPushed = true
                await commit.commit(
                  directory: d,
                  message: 'Commit message 2',
                  doStage: true,
                  ammendWhenNotPushed: true,
                  ggLog: messages.add,
                );

                // Commit count should have increased
                // because we did push the previous release
                final count2 = await commitCount.get(
                  ggLog: messages.add,
                  directory: d,
                );
                expect(count2, count1 + 1);

                // Commit message should be the new one,
                // because we did add an additional commit
                final commitMessage2 = await headMessage.get(
                  ggLog: messages.add,
                  directory: d,
                );
                expect(commitMessage2, 'Commit message 2');
              },
            );
          },
        );

        group('when ammendWhenNotPushed is true and branch has no remote', () {
          test('and it should not overwrite the last commit message', () async {
            // Create a new local branch which does not has a remote branch
            await createBranch(d, 'feature1');

            // Let's modify a file
            await addAndCommitSampleFile(
              d,
              fileName: 'file1.txt',
              message: 'Commit message 0',
            );

            // Count the number of commits
            final count0 = await commitCount.get(
              ggLog: messages.add,
              directory: d,
            );

            // Modify the file again
            File('${d.path}/file1.txt').writeAsStringSync('Change 2!');

            // Commit the file again with ammendWhenNotPushed = true
            await commit.commit(
              directory: d,
              message: 'Commit message 1',
              doStage: true,
              ammendWhenNotPushed: true,
              ggLog: messages.add,
            );

            // Commit count should not have increased
            // because we did not push yet.
            final count1 = await commitCount.get(
              ggLog: messages.add,
              directory: d,
            );
            expect(count1, count0);

            // Commit message should be the previous one.
            // because the commit was ammended
            final commitMessage1 = await headMessage.get(
              ggLog: messages.add,
              directory: d,
            );
            expect(commitMessage1, 'Commit message 0');
          });
        });
      });
    });

    group('should wait for ".git/index.lock"', () {
      // .......................................................................
      /// Creates a commit command which does not wait too long for the lock
      Commit commitWithLockTimeout(Duration timeout) => Commit(
        ggLog: messages.add,
        isLocked: IsLocked(
          ggLog: messages.add,
          timeout: timeout,
          interval: const Duration(milliseconds: 10),
        ),
      );

      test('before staging and committing', () async {
        commit = commitWithLockTimeout(const Duration(seconds: 5));

        // Let's modify a file
        await addFileWithoutCommitting(d, fileName: 'file1.txt');

        // Another git process is writing the index
        final lockFile = commit.isLocked.lockFile(d);
        await lockFile.create(recursive: true);

        // The other git process finishes a little bit later
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 50),
          ).then((_) async => lockFile.delete()),
        );

        // The commit waits for the lock and succeeds afterwards
        await commit.commit(
          directory: d,
          message: commitMessage,
          doStage: true,
          ggLog: messages.add,
        );

        expect(messages.where((m) => m.contains('Waiting until ')), isNotEmpty);
        expect(messages.first, contains(lockFile.path));
        expect(await modifiedFiles(d), <String>[]);
      });

      test('and throw when the lock does not disappear', () async {
        commit = commitWithLockTimeout(const Duration(milliseconds: 50));

        // Let's modify a file
        await addFileWithoutCommitting(d, fileName: 'file1.txt');

        // Another git process does not release the index
        await commit.isLocked.lockFile(d).create(recursive: true);

        await expectLater(
          commit.commit(
            directory: d,
            message: commitMessage,
            doStage: true,
            ggLog: messages.add,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('did not disappear within'),
            ),
          ),
        );

        // Nothing was committed
        expect(await modifiedFiles(d), ['file1.txt']);
      });
    });

    group('exec(directory, ggLog)', () {
      group('with ammend=false', () {
        test('should call commit', () async {
          final runner = CommandRunner<void>('gg', 'Test');
          runner.addCommand(commit);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');
          expect(await modifiedFiles(d), ['file1.txt']);

          // Commit the file
          await runner.run([
            'commit',
            '-i',
            d.path,
            '-m',
            'Commit message',
            '-s',
          ]);

          expect(await modifiedFiles(d), <String>[]);
        });
      });

      group('with ammend=true', () {
        test('should call commit --ammend', () async {
          final runner = CommandRunner<void>('gg', 'Test');
          runner.addCommand(commit);

          // Make first commit
          await addAndCommitSampleFile(d, fileName: 'file1.txt');

          // Count the commits
          final count0 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );
          expect(count0, 2);

          // Let's modify a file
          await addFileWithoutCommitting(d, fileName: 'file1.txt');
          expect(await modifiedFiles(d), ['file1.txt']);

          // Commit the file
          await runner.run([
            'commit',
            '-i',
            d.path,
            '-m',
            'Commit message',
            '-s',
            '-a',
          ]);

          // Everything is committed
          expect(await modifiedFiles(d), <String>[]);

          // Commit count should be the same
          final count1 = await commitCount.get(
            ggLog: messages.add,
            directory: d,
          );
          expect(count1, count0);
        });
      });
    });

    group('commit(..., paths)', () {
      test('commits only the given paths and leaves the rest dirty', () async {
        await addAndCommitSampleFile(d, fileName: 'mine.txt', content: 'a');
        await File('${d.path}/mine.txt').writeAsString('changed by the user');
        await File('${d.path}/pubspec.lock').writeAsString('generated');

        await commit.commit(
          ggLog: messages.add,
          directory: d,
          doStage: true,
          message: '#gg: Update pubspec.lock',
          paths: <String>['pubspec.lock'],
        );

        // The lock file is in — the user's file is untouched and still dirty.
        final committed = await _filesOfHead(d);
        expect(committed, <String>['pubspec.lock']);
        expect(await modifiedFiles(d), contains('mine.txt'));
      });

      test('stages the deletion and the addition of a rename', () async {
        await addAndCommitSampleFile(d, fileName: 'old.txt', content: 'a');
        File('${d.path}/old.txt').renameSync('${d.path}/new.txt');

        await commit.commit(
          ggLog: messages.add,
          directory: d,
          doStage: true,
          message: '#gg: Rename',
          paths: <String>['new.txt', 'old.txt'],
        );

        expect(await _filesOfHead(d), containsAll(<String>['new.txt']));
        expect(await modifiedFiles(d), <String>[]);
      });

      test('ignores what was staged outside the pathspec', () async {
        await addAndCommitSampleFile(d, fileName: 'mine.txt', content: 'a');
        await File('${d.path}/mine.txt').writeAsString('user work');
        await File('${d.path}/pubspec.lock').writeAsString('generated');

        // Someone staged the user's file before gg got here.
        await Process.run('git', ['add', 'mine.txt'], workingDirectory: d.path);

        await commit.commit(
          ggLog: messages.add,
          directory: d,
          doStage: true,
          message: '#gg: Update pubspec.lock',
          paths: <String>['pubspec.lock'],
        );

        expect(await _filesOfHead(d), <String>['pubspec.lock']);
      });

      test('throws on an empty path list instead of committing all', () async {
        await File('${d.path}/mine.txt').writeAsString('user work');

        await expectLater(
          commit.commit(
            ggLog: messages.add,
            directory: d,
            doStage: true,
            message: '#gg: Nothing of mine changed',
            paths: <String>[],
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Nothing to commit'),
            ),
          ),
        );

        // Nothing was committed — the user's file is still dirty.
        expect(await modifiedFiles(d), contains('mine.txt'));
      });

      test('refuses a partial commit while a merge is in progress', () async {
        await addAndCommitSampleFile(d, fileName: 'a.txt', content: 'base');

        // Simulate the state git leaves behind during a conflicted merge.
        await File('${d.path}/.git/MERGE_HEAD').writeAsString('deadbeef\n');
        await File('${d.path}/pubspec.lock').writeAsString('generated');

        await expectLater(
          commit.commit(
            ggLog: messages.add,
            directory: d,
            doStage: true,
            message: '#gg: Update pubspec.lock',
            paths: <String>['pubspec.lock'],
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('partial commit during a merge'),
            ),
          ),
        );
      });

      test('names the rebase when a rebase is in progress', () async {
        await addAndCommitSampleFile(d, fileName: 'a.txt', content: 'base');
        await Directory('${d.path}/.git/rebase-merge').create();
        await File('${d.path}/pubspec.lock').writeAsString('generated');

        await expectLater(
          commit.commit(
            ggLog: messages.add,
            directory: d,
            doStage: true,
            message: '#gg: Update pubspec.lock',
            paths: <String>['pubspec.lock'],
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('partial commit during a rebase'),
            ),
          ),
        );
      });

      test('a null path list still commits the whole tree', () async {
        await File('${d.path}/mine.txt').writeAsString('user work');
        await File('${d.path}/pubspec.lock').writeAsString('generated');

        await commit.commit(
          ggLog: messages.add,
          directory: d,
          doStage: true,
          message: 'Everything',
        );

        expect(await modifiedFiles(d), <String>[]);
      });
    });
  });
}

// .............................................................................
/// The files touched by the HEAD commit of [directory].
Future<List<String>> _filesOfHead(Directory directory) async {
  final result = await Process.run('git', [
    'show',
    '--name-only',
    '--format=',
    'HEAD',
  ], workingDirectory: directory.path);

  return result.stdout
      .toString()
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}
