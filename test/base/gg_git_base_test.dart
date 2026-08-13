// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_process/gg_process.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import 'package:gg_git/src/test_helpers/test_helpers.dart';

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late GgGitCommandExample ggGit;
  late Directory d;

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    ggGit = GgGitCommandExample(
      ggLog: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(ggGit);
  }

  // ...........................................................................
  setUp(() async {
    runner = CommandRunner<void>('test', 'test');
    d = await initTestDir();
    messages.clear();
  });

  group('GgGitCommandExample', () {
    // #########################################################################
    group('run(), get()', () {
      group('should throw', () {
        // .....................................................................
        group('if directory does not exist', () {
          test('specified via --input', () async {
            initCommand();
            await expectLater(
              runner.run(['example', '--input', 'xyz']),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  'Directory "xyz" does not exist.',
                ),
              ),
            );
          });

          test('specified via constructor', () async {
            initCommand();
            await expectLater(
              ggGit.exec(directory: Directory('xyz'), ggLog: messages.add),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.message,
                  'message',
                  'Directory "xyz" does not exist.',
                ),
              ),
            );
          });
        });

        // .....................................................................
        test('if directory is not a git repository', () async {
          await initTestDir();
          initCommand();
          await expectLater(
            runner.run(['example', '--input', d.path]),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'Directory "test" is not a git repository.',
              ),
            ),
          );
        });
      });
    });

    // #########################################################################
    test('should succeed', () async {
      await initTestDir();
      await initGit(d);
      initCommand();
      await runner.run(['example', '--input', d.path]);
      expect(messages, ['Example executed for "test".']);
      expect(exitCode, 0);
    });
  });

  // ###########################################################################
  group('waitUntilUnlocked(directory, ggLog)', () {
    test('creates an IsLocked instance when none is injected', () async {
      initCommand();
      expect(ggGit.isLocked.timeout, IsLocked.defaultTimeout);
      expect(ggGit.isLocked.interval, IsLocked.defaultInterval);
    });

    test('uses the injected IsLocked instance', () async {
      final isLocked = IsLocked(
        ggLog: messages.add,
        timeout: const Duration(milliseconds: 100),
        interval: const Duration(milliseconds: 10),
      );

      ggGit = GgGitCommandExample(ggLog: messages.add, isLocked: isLocked);
      expect(ggGit.isLocked, same(isLocked));
    });

    test('returns when the repo is not locked', () async {
      await initGit(d);
      initCommand();
      await ggGit.waitUntilUnlocked(directory: d);
      expect(messages, isEmpty);
    });

    test('throws when the lock file does not disappear', () async {
      await initGit(d);

      ggGit = GgGitCommandExample(
        ggLog: messages.add,
        isLocked: IsLocked(
          ggLog: messages.add,
          timeout: const Duration(milliseconds: 50),
          interval: const Duration(milliseconds: 10),
        ),
      );

      await File(join(d.path, '.git', 'index.lock')).create(recursive: true);

      await expectLater(
        ggGit.waitUntilUnlocked(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('did not disappear within'),
          ),
        ),
      );
    });
  });
}
