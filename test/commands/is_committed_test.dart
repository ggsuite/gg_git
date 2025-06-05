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
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsCommitted isCommitted;
  late Directory tmp;
  late Directory d;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    isCommitted = IsCommitted(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(isCommitted);
  }

  // ...........................................................................
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gg_test');
    d = Directory('${tmp.path}/test')..createSync();
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('IsCommitted', () {
    // #########################################################################
    group('run(), get()', () {
      test('should throw if "git status" fails', () async {
        final failingProcessWrapper = MockGgProcessWrapper();
        await initGit(d);
        initCommand(processWrapper: failingProcessWrapper);

        when(
          () => failingProcessWrapper.run('git', [
            'status',
            '--porcelain',
          ], workingDirectory: d.path),
        ).thenAnswer(
          (_) async =>
              ProcessResult(1, 1, 'git status failed', 'git status failed'),
        );

        late String exception;

        try {
          await isCommitted.get(directory: d, ggLog: messages.add);
        } catch (e) {
          exception = e.toString();
        }

        expect(
          exception,
          'Exception: Could not run "git status" in "test": '
          'git status failed',
        );
      });

      // .......................................................................
      group('should return', () {
        group('false', () {
          test('if there are uncommitted changes', () async {
            await initGit(d);
            await addFileWithoutCommitting(d);
            initCommand();

            await expectLater(
              runner.run(['is-committed', '--input', d.path]),
              throwsA(
                isA<Exception>().having(
                  (e) => e.toString(),
                  'message',
                  contains('There are uncommmited changes.'),
                ),
              ),
            );
          });
        });

        // .....................................................................
        group('true', () {
          group('if everything is committed', () {
            test('with inputDir from --input args', () async {
              await initGit(d);
              initCommand();
              await runner.run(['is-committed', '--input', d.path]);
              expect(messages.last, contains('✅ Everything is committed.'));
            });

            test('with inputDir taken from constructor', () async {
              await initGit(d);
              initCommand();
              final result = await isCommitted.get(
                directory: d,
                ggLog: messages.add,
              );
              expect(result, isTrue);
            });
          });
        });
      });
    });
  });
}
