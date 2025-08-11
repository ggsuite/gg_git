// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late IsEolLf isEolLf;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    isEolLf = IsEolLf(ggLog: messages.add);
    await initGit(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('IsEolLf', () {
    late String gitAttributesPath;
    late File gitAttributesFile;

    setUp(() {
      gitAttributesPath = join(d.path, '.gitattributes');
      gitAttributesFile = File(gitAttributesPath);
    });

    group('get(ggLog, directory)', () {
      group('returns true', () {
        test('when eol is set to LF', () async {
          await gitAttributesFile.writeAsString('* eol=lf');
          final result = await isEolLf.get(ggLog: messages.add, directory: d);
          expect(result, isTrue);
        });

        test('when eol is set to auto', () async {
          await gitAttributesFile.writeAsString('* text=auto');
          final result = await isEolLf.get(ggLog: messages.add, directory: d);
          expect(result, isTrue);
        });
      });

      group('returns false', () {
        test('when eol is neither set to auto nor to lf', () async {
          final result = await isEolLf.get(ggLog: messages.add, directory: d);
          expect(result, isFalse);
        });
      });
    });

    group('exec(directory, ggLog)', () {
      test('should allow to run the command from command line', () async {
        await initGit(d);
        await addAndCommitSampleFile(d);
        await enableEolLf(d);

        final runner = CommandRunner<void>('test', 'test');
        runner.addCommand(isEolLf);

        await runner.run(['is-eol-lf', '-i', d.path]);

        expect(messages.length, 2);
        expect(messages.first, contains('⌛️ Is line feed enabled?'));
        expect(messages.last, contains('✅ Is line feed enabled?'));
      });

      test('prints error messages', () async {
        final runner = CommandRunner<void>('test', 'test');
        runner.addCommand(isEolLf);

        // No git initialized
        // await enableEolLf(d);
        await runner.run(['is-eol-lf', '-i', d.path]);

        expect(messages.length, 2);
        expect(messages.first, contains('⌛️ Is line feed enabled?'));
        expect(messages.last, contains('❌ Is line feed enabled?'));
      });
    });

    group('throwWhenNotLf()', () {
      test('throws an error when LF is not enabled', () async {
        var message = <String>[];
        try {
          await isEolLf.throwWhenNotLf(directory: d);
        } catch (e) {
          message = (e as dynamic).message.toString().split('\n');
        }

        expect(message, [
          'Git automatic EOL conversion is OFF.',
          '  1. Create a file ".gitattributes" in the root of this repo',
          '  2. Open .gitattributes with a text editor.',
          '  3. Add the following line:',
          '      * text=auto eol=lf',
        ]);
      });

      test('throws not, when LF is enabled', () async {
        await enableEolLf(d);
        await isEolLf.throwWhenNotLf(directory: d);
      });
    });
  });
}
