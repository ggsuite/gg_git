// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late IsLocked isLocked;
  final messages = <String>[];

  // ...........................................................................
  /// Creates the ".git/index.lock" file
  Future<File> createLockFile() async {
    final file = isLocked.lockFile(d);
    await file.create(recursive: true);
    return file;
  }

  // ...........................................................................
  /// Deletes [file] after [delay]
  void deleteDelayed(File file, [int delay = 50]) => unawaited(
    Future<void>.delayed(Duration(milliseconds: delay)).then((_) async {
      await file.delete();
    }),
  );

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);

    isLocked = IsLocked(
      ggLog: messages.add,
      timeout: const Duration(milliseconds: 300),
      interval: const Duration(milliseconds: 10),
    );
  });

  tearDown(() async => d.delete(recursive: true));

  group('IsLocked', () {
    group('lockFile(directory)', () {
      test('returns ".git/index.lock" within the directory', () {
        expect(
          isLocked.lockFile(d).path,
          join(canonicalize(d.path), '.git', 'index.lock'),
        );
      });
    });

    group('get(directory, ggLog)', () {
      test('returns false when the repo is not locked', () async {
        expect(await isLocked.get(directory: d, ggLog: messages.add), isFalse);
      });

      test('returns true when ".git/index.lock" exists', () async {
        await createLockFile();
        expect(await isLocked.get(directory: d, ggLog: messages.add), isTrue);
      });
    });

    group('exec(directory, ggLog)', () {
      test('logs the lock state', () async {
        final runner = CommandRunner<void>('gg', 'Test')..addCommand(isLocked);

        await runner.run(['is-locked', '-i', d.path]);
        expect(messages.last, 'false');

        await createLockFile();
        await runner.run(['is-locked', '-i', d.path]);
        expect(messages.last, 'true');
      });
    });

    group('waitUntilUnlocked(directory, ggLog)', () {
      test('returns immediately and logs nothing when not locked', () async {
        await isLocked.waitUntilUnlocked(directory: d, ggLog: messages.add);
        expect(messages, isEmpty);
      });

      test('waits until the lock file disappears', () async {
        final file = await createLockFile();
        deleteDelayed(file);

        await isLocked.waitUntilUnlocked(directory: d, ggLog: messages.add);

        expect(await file.exists(), isFalse);
        expect(messages, hasLength(1));
        expect(
          messages.first,
          yellow('Waiting until ') + blue(file.path) + yellow(' disappears.'),
        );
      });

      test('logs to the ggLog given to the constructor by default', () async {
        final file = await createLockFile();
        deleteDelayed(file);

        await isLocked.waitUntilUnlocked(directory: d);

        expect(messages, hasLength(1));
        expect(messages.first, contains('Waiting until '));
      });

      test('throws when the lock is not removed within the timeout', () async {
        final file = await createLockFile();

        late String exception;
        try {
          await isLocked.waitUntilUnlocked(directory: d, ggLog: messages.add);
        } catch (e) {
          exception = e.toString();
        }

        expect(exception, contains(file.path));
        expect(exception, contains('did not disappear within'));
        expect(
          exception,
          contains('Another git process seems to be running in this'),
        );
      });

      test('waits two minutes by default', () {
        expect(IsLocked.defaultTimeout, const Duration(minutes: 2));
        expect(IsLocked(ggLog: messages.add).timeout, IsLocked.defaultTimeout);
        expect(
          IsLocked(ggLog: messages.add).interval,
          IsLocked.defaultInterval,
        );
      });
    });
  });
}
