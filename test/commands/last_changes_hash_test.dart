// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/last_changes_hash.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:test/test.dart';

// .............................................................................
/// Runs the real git and records the files each `git hash-object` call was
/// asked to hash. With [failBatches] a call for several files fails, as git
/// does when it cannot read one of them.
class _RecordingProcessWrapper extends GgProcessWrapper {
  _RecordingProcessWrapper({this.failBatches = false});

  final bool failBatches;

  /// The files of each `git hash-object` call.
  final List<List<String>> hashedFiles = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) async {
    if (arguments.first == 'hash-object') {
      final files = arguments.skip(2).toList();
      hashedFiles.add(files);
      if (failBatches && files.length > 1) {
        return ProcessResult(0, 128, '', 'fatal: could not open a file');
      }
    }

    return super.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }
}

void main() {
  late Directory d;
  late LastChangesHash lastChangesHahs;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    lastChangesHahs = LastChangesHash(ggLog: messages.add);
    await initGit(d, isEolLfEnabled: false);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('LastChangesHash', () {
    group('get(ggLog, directory, ignoredFiles, logDetails)', () {
      test('should work in a repository without any commits', () async {
        await initGit(d, isEolLfEnabled: false);
        await enableEolLf(d);

        // `git ls-files -s` prints nothing here. Must not throw a RangeError.
        final hash = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );
        expect(hash, isA<int>());
      });

      test('should return a 64bit hash summarizing the changes '
          'since the last commit.', () async {
        await initGit(d, isEolLfEnabled: false);
        await addAndCommitSampleFile(d);

        // Throws when automatic EOL conversion is off
        var message = <String>[];
        try {
          await lastChangesHahs.get(ggLog: messages.add, directory: d);
        } catch (e) {
          message = rmControls((e as dynamic).message.toString()).split('\n');
        }
        expect(message, [
          'Git automatic EOL conversion is OFF.',
          '  1. Create a file ".gitattributes" in the root of this repo',
          '  2. Open .gitattributes with a text editor.',
          '  3. Add the following line:',
          '      * text=auto eol=lf',
        ]);

        // Switch on automatic EOL conversion
        await enableEolLf(d);

        // Let's get the first hash
        final hash0 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );
        expect(hash0, -7537449727184798886);

        // Add some modifications
        await addFileWithoutCommitting(
          d,
          fileName: 'file1.txt',
          content: 'content1',
        );

        // Whe should get a different hash
        final hash1 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );
        expect(hash1, isNot(hash0));
        expect(hash1, 1921129522768528912);

        // Request the hash wile ignoring 'file1.txt'
        // We should get the former hash
        final hash1a = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
          ignoreFiles: ['file1.txt'],
        );
        expect(hash1a, hash0);

        // Let's commit the changes
        await commitFile(d, 'file1.txt', message: 'commit file1.txt');

        // The lastChangesHash should be the same as the first hash
        final hash2 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );

        expect(hash2, hash1);

        // Modify 'file1.txt' again
        await addFileWithoutCommitting(
          d,
          fileName: 'file1.txt',
          content: 'line1\nline2\n',
        );

        // Whe should get a different hash
        final hash3 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );

        expect(hash3, isNot(hash2));

        // Check the file in with different line endings
        await addFileWithoutCommitting(
          d,
          fileName: 'file1.txt',
          content: 'line1\r\nline2\r\n',
        );

        // Whe should get the same hash again
        final hash3a = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );

        expect(hash3a, hash3);

        // Revert the last change
        await addFileWithoutCommitting(
          d,
          fileName: 'file1.txt',
          content: 'content1',
        );

        // We should get the same hash as before
        final hash4 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );
        expect(hash4, hash2);

        // Delete the file
        await deleteFileAndCommit(d, 'file1.txt');

        // Calculate the hash
        final hash5 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );

        // The hash should be different
        expect(hash5, isNot(hash4));

        // Add a binary file
        await addFileWithoutCommitting(
          d,
          fileName: 'file2.bin',
          content: 'content2',
        );

        // We should get a diferent hash
        final hash6 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );
        expect(hash6, isNot(hash5));

        // Create another ignored file
        await addFileWithoutCommitting(
          d,
          fileName: 'ignored.txt',
          content: 'content3',
        );

        // The hash should still be hash6
        final hash6b = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
          ignoreFiles: ['ignored.txt'],
        );
        expect(hash6b, hash6);

        // Commit the ignored file
        await commitFile(d, 'ignored.txt');

        // The hash should still be hash6
        final hash6c = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
          ignoreFiles: ['ignored.txt'],
        );
        expect(hash6c, hash6);
      });

      test(
        'should ignore every file below a directory ending with a slash',
        () async {
          await enableEolLf(d);
          await addAndCommitSampleFile(d, fileName: 'file1.txt');
          final hashBefore = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
            ignoreFiles: ['.gg/'],
          );

          // Files below the directory do not change the hash — untracked ...
          Directory('${d.path}/.gg').createSync();
          await addFileWithoutCommitting(
            d,
            fileName: '.gg/publish_config.json',
            content: '{}',
          );
          expect(
            await lastChangesHahs.get(
              ggLog: messages.add,
              directory: d,
              ignoreFiles: ['.gg/'],
            ),
            hashBefore,
          );

          // ... and committed.
          await commitFile(d, '.gg/publish_config.json');
          expect(
            await lastChangesHahs.get(
              ggLog: messages.add,
              directory: d,
              ignoreFiles: ['.gg/'],
            ),
            hashBefore,
          );

          // Without the entry the file counts.
          expect(
            await lastChangesHahs.get(ggLog: messages.add, directory: d),
            isNot(hashBefore),
          );
        },
      );

      group('should log details', () {
        test('when logDetails is true', () async {
          // Switch on automatic EOL conversion
          await enableEolLf(d);

          await addAndCommitSampleFile(d);

          // Let's get the first hash
          final hash0 = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
            logDetails: true,
          );

          expect(hash0, -7537449727184798886);
          expect(messages, [
            '.gitattributes 6313b56c57848efce05faa7aa7e901ccfc2886ea\n'
                'test.txt eed7e79a92ce81c482fe5865098047e0293a31b2',
          ]);
        });

        test('but not when logDetails is false', () async {
          // Switch on automatic EOL conversion
          await enableEolLf(d);

          await addAndCommitSampleFile(d);

          // Let's get the first hash
          final hash0 = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
            logDetails: false,
          );

          expect(hash0, -7537449727184798886);
          expect(messages, <String>[]);
        });
      });

      group('should ignore unstaged files', () {
        test('when ignoreUnstaged is set to true', () async {
          // Switch on automatic EOL conversion
          await enableEolLf(d);

          // Let's get the first hash
          final hash0 = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(hash0, 1791652410119668049);

          // Add a file without committing
          await addFileWithoutCommitting(d);

          // Let's get the first hash
          final hash1 = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
            ignoreUnstaged: true,
          );

          expect(hash1, hash0);
        });

        test('but not when ignoreUnstaged is set to false', () async {
          // Switch on automatic EOL conversion
          await enableEolLf(d);

          // Let's get the first hash
          final hash0 = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(hash0, 1791652410119668049);

          // Add a file without committing
          await addFileWithoutCommitting(d);

          // Let's get the first hash
          final hash1 = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
            ignoreUnstaged: false,
          );

          expect(hash1, isNot(hash0));
        });
      });

      group('hashes the unstaged files', () {
        late _RecordingProcessWrapper processWrapper;

        /// The hash as a run asking git for one file at a time gives it.
        Future<int> hashFileByFile() => LastChangesHash(
          ggLog: messages.add,
          processWrapper: _RecordingProcessWrapper(failBatches: true),
        ).get(ggLog: messages.add, directory: d);

        setUp(() async {
          processWrapper = _RecordingProcessWrapper();
          lastChangesHahs = LastChangesHash(
            ggLog: messages.add,
            processWrapper: processWrapper,
          );
          await enableEolLf(d);
          await addAndCommitSampleFile(d);
        });

        test('with one git call for all of them', () async {
          for (var i = 0; i < 5; i++) {
            await addFileWithoutCommitting(
              d,
              fileName: 'file$i.txt',
              content: 'content$i',
            );
          }

          final hash = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(processWrapper.hashedFiles, [
            ['file0.txt', 'file1.txt', 'file2.txt', 'file3.txt', 'file4.txt'],
          ]);
          expect(hash, await hashFileByFile());
        });

        test('without asking git when nothing changed', () async {
          await lastChangesHahs.get(ggLog: messages.add, directory: d);
          expect(processWrapper.hashedFiles, isEmpty);
        });

        test('with several git calls when the names fill a command line, '
            'in the order of the files', () async {
          // 70 names of 100 characters: more than one command line takes.
          final names = [
            for (var i = 0; i < 70; i++)
              '${'$i'.padLeft(3, '0')}_${'x' * 92}.txt',
          ];
          for (final name in names) {
            File('${d.path}/$name').writeAsStringSync('content of $name');
          }

          final hash = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(processWrapper.hashedFiles, hasLength(2));
          expect(processWrapper.hashedFiles.expand((files) => files), names);
          for (final files in processWrapper.hashedFiles) {
            expect(
              files.join(' ').length,
              lessThanOrEqualTo(LastChangesHash.maxCommandLineLength),
            );
          }
          expect(hash, await hashFileByFile());
        });

        test('with an empty hash for a deleted file, without asking git '
            'about it', () async {
          await addFileWithoutCommitting(d, fileName: 'kept.txt');
          final before = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );
          processWrapper.hashedFiles.clear();

          File('${d.path}/$sampleFileName').deleteSync();
          final after = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );

          expect(processWrapper.hashedFiles, [
            ['kept.txt'],
          ]);
          expect(after, isNot(before));
        });

        test('file by file when git cannot hash them at once', () async {
          await addFileWithoutCommitting(d, fileName: 'a.txt', content: 'a');
          await addFileWithoutCommitting(d, fileName: 'b.txt', content: 'b');
          final expected = await lastChangesHahs.get(
            ggLog: messages.add,
            directory: d,
          );

          final failing = _RecordingProcessWrapper(failBatches: true);
          final hash = await LastChangesHash(
            ggLog: messages.add,
            processWrapper: failing,
          ).get(ggLog: messages.add, directory: d);

          expect(failing.hashedFiles, [
            ['a.txt', 'b.txt'],
            ['a.txt'],
            ['b.txt'],
          ]);
          expect(hash, expected);
        });
      });
    });

    group('exec(directory, ggLog)', () {
      test('should allow to run the command from command line', () async {
        await initGit(d);
        await addAndCommitSampleFile(d);
        await enableEolLf(d);

        final runner = CommandRunner<void>('test', 'test');
        runner.addCommand(lastChangesHahs);

        await runner.run(['last-changes-hash', '-i', d.path, '-v']);
        expect(messages.length, 2);

        final hashString = messages.last;
        final hash = int.tryParse(hashString);
        expect(hash, isNotNull);
        expect(messages.first.split('\n'), [
          '.gitattributes 6313b56c57848efce05faa7aa7e901ccfc2886ea',
          'test.txt eed7e79a92ce81c482fe5865098047e0293a31b2',
        ]);
      });

      group('with option ignoreUnstaged', () {
        test('should allow to run the command from command line', () async {
          await initGit(d);
          await addFileWithoutCommitting(d);
          await enableEolLf(d);

          final runner = CommandRunner<void>('test', 'test');
          runner.addCommand(lastChangesHahs);

          await runner.run(['last-changes-hash', '-i', d.path, '-v', '-u']);
          expect(messages.length, 2);

          final hashString = messages.last;
          final hash = int.tryParse(hashString);
          expect(hash, isNotNull);
          expect(messages.first.split('\n'), [
            '.gitattributes 6313b56c57848efce05faa7aa7e901ccfc2886ea',
          ]);
        });
      });
    });
  });
}
