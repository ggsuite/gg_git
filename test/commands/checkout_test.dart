// @license
// Copyright (c) 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
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
  final messages = <String>[];
  late MockGgProcessWrapper processWrapper;
  late Checkout checkout;

  setUp(() async {
    d = await initTestDir();
    messages.clear();
    processWrapper = MockGgProcessWrapper();
    checkout = Checkout(ggLog: messages.add, processWrapper: processWrapper);
  });

  tearDown(() => d.deleteSync(recursive: true));

  group('Checkout', () {
    test('throws when no branch is given', () async {
      expect(
        () => checkout.get(directory: d, ggLog: messages.add),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the branch name is empty', () async {
      expect(
        () => checkout.get(directory: d, ggLog: messages.add, branch: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('checks out the existing branch on success', () async {
      when(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      await checkout.get(directory: d, ggLog: messages.add, branch: 'feat');

      verify(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).called(1);
    });

    test('throws when the checkout fails', () async {
      when(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 1, '', 'no such branch'));

      expect(
        () => checkout.get(directory: d, ggLog: messages.add, branch: 'feat'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not checkout "feat"'),
          ),
        ),
      );
    });

    test('exec delegates to get', () async {
      when(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      await checkout.exec(directory: d, ggLog: messages.add, branch: 'feat');

      verify(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).called(1);
    });

    test('reads the branch from the positional CLI argument', () async {
      when(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      final runner = CommandRunner<void>('gg', 'gg')..addCommand(checkout);
      await runner.run(['checkout', '-i', d.path, 'feat']);

      verify(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).called(1);
    });

    test('waits until ".git/index.lock" disappears', () async {
      // "git checkout" writes the index and needs the index lock
      checkout = Checkout(
        ggLog: messages.add,
        processWrapper: processWrapper,
        isLocked: IsLocked(
          ggLog: messages.add,
          timeout: const Duration(seconds: 5),
          interval: const Duration(milliseconds: 10),
        ),
      );

      when(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      // Another git process is writing the index
      final lockFile = checkout.isLocked.lockFile(d);
      await lockFile.create(recursive: true);

      // The other git process finishes a little bit later
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 50),
        ).then((_) async => lockFile.delete()),
      );

      await checkout.get(directory: d, ggLog: messages.add, branch: 'feat');

      expect(messages.first, contains('Waiting until '));
      expect(messages.first, contains(lockFile.path));
      verify(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).called(1);
    });

    test('throws when ".git/index.lock" does not disappear', () async {
      checkout = Checkout(
        ggLog: messages.add,
        processWrapper: processWrapper,
        isLocked: IsLocked(
          ggLog: messages.add,
          timeout: const Duration(milliseconds: 50),
          interval: const Duration(milliseconds: 10),
        ),
      );

      await checkout.isLocked.lockFile(d).create(recursive: true);

      await expectLater(
        checkout.get(directory: d, ggLog: messages.add, branch: 'feat'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('did not disappear within'),
          ),
        ),
      );

      verifyNever(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      );
    });

    test('reports stdout when checkout fails with empty stderr', () async {
      when(
        () => processWrapper.run('git', [
          'checkout',
          'feat',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 1, 'pathspec not found', ''));

      expect(
        () => checkout.get(directory: d, ggLog: messages.add, branch: 'feat'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('pathspec not found'),
          ),
        ),
      );
    });
  });
}
