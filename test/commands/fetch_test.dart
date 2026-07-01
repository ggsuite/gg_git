// @license
// Copyright (c) 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  final messages = <String>[];
  late MockGgProcessWrapper processWrapper;
  late Fetch fetch;

  setUp(() async {
    d = await initTestDir();
    messages.clear();
    processWrapper = MockGgProcessWrapper();
    fetch = Fetch(ggLog: messages.add, processWrapper: processWrapper);
  });

  tearDown(() => d.deleteSync(recursive: true));

  group('Fetch', () {
    test('runs "git fetch" on success', () async {
      when(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      await fetch.get(directory: d, ggLog: messages.add);

      verify(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).called(1);
    });

    test('throws when fetch fails', () async {
      when(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 1, '', 'offline'));

      expect(
        () => fetch.get(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not fetch in'),
          ),
        ),
      );
    });

    test('exec delegates to get', () async {
      when(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, '', ''));

      await fetch.exec(directory: d, ggLog: messages.add);

      verify(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).called(1);
    });

    test('reports stdout when fetch fails with empty stderr', () async {
      when(
        () => processWrapper.run('git', ['fetch'], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 1, 'fatal: offline', ''));

      expect(
        () => fetch.get(directory: d, ggLog: messages.add),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('fatal: offline'),
          ),
        ),
      );
    });
  });
}
