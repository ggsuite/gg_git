// @license
// Copyright (c) 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
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
  late Directory d;
  final messages = <String>[];
  late MockGgProcessWrapper processWrapper;
  late ShowFile showFile;

  setUp(() async {
    d = await initTestDir();
    messages.clear();
    processWrapper = MockGgProcessWrapper();
    showFile = ShowFile(ggLog: messages.add, processWrapper: processWrapper);
  });

  tearDown(() => d.deleteSync(recursive: true));

  group('ShowFile', () {
    test('throws when the ref is missing', () async {
      expect(
        () => showFile.get(directory: d, ggLog: messages.add, filePath: 'a'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws when the filePath is missing', () async {
      expect(
        () => showFile.get(directory: d, ggLog: messages.add, ref: 'origin/x'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns the file content on success', () async {
      when(
        () => processWrapper.run('git', [
          'show',
          'origin/feat:.gg/.ticket.json',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, '{"a":1}', ''));

      final content = await showFile.get(
        directory: d,
        ggLog: messages.add,
        ref: 'origin/feat',
        filePath: '.gg/.ticket.json',
      );
      expect(content, '{"a":1}');
    });

    test('returns null when the file is absent at the ref', () async {
      when(
        () => processWrapper.run('git', [
          'show',
          'origin/feat:.gg/.ticket.json',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 128, '', 'not found'));

      final content = await showFile.get(
        directory: d,
        ggLog: messages.add,
        ref: 'origin/feat',
        filePath: '.gg/.ticket.json',
      );
      expect(content, isNull);
    });

    test('exec delegates to get', () async {
      when(
        () => processWrapper.run('git', [
          'show',
          'origin/feat:f.txt',
        ], workingDirectory: d.path),
      ).thenAnswer((_) async => ProcessResult(1, 0, 'hi', ''));

      final content = await showFile.exec(
        directory: d,
        ggLog: messages.add,
        ref: 'origin/feat',
        filePath: 'f.txt',
      );
      expect(content, 'hi');
    });

    test('reads ref and filePath from positional CLI arguments', () async {
      when(
        () => processWrapper.run('git', [
          'show',
          'origin/feat:f.txt',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).thenAnswer((_) async => ProcessResult(1, 0, 'hi', ''));

      final runner = CommandRunner<void>('gg', 'gg')..addCommand(showFile);
      await runner.run(['show-file', '-i', d.path, 'origin/feat', 'f.txt']);

      verify(
        () => processWrapper.run('git', [
          'show',
          'origin/feat:f.txt',
        ], workingDirectory: any(named: 'workingDirectory')),
      ).called(1);
    });
  });
}
