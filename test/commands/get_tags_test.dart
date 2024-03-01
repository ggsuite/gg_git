// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/get_tags.dart';
import 'package:gg_process/gg_process.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  late Directory d;
  final messages = <String>[];

  setUp(() {
    d = initTestDir();
    messages.clear();
  });

  Future<List<String>> getFromHead() => GetTags.fromHead(
        directory: d.path,
        processWrapper: const GgProcessWrapper(),
        log: (msg) => messages.add(msg),
      );

  Future<List<String>> getAll({bool sort = true}) => GetTags.all(
        directory: d.path,
        processWrapper: const GgProcessWrapper(),
        log: (msg) => messages.add(msg),
      );

  group('HeadTags', () {
    group('fromHead(...)', () {
      group('should throw', () {
        test('when directory is not a git repo', () async {
          await expectLater(
            getFromHead(),
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

      group('should return nothing', () {
        test('when no tags are available', () async {
          await initGit(d);
          final result = await getFromHead();
          expect(result, isEmpty);
          expect(messages, isEmpty);
        });
      });

      group('should return', () {
        group('one', () {
          test('when available', () async {
            await initGit(d);
            addAndCommitSampleFile(d);
            await addTag(d, 'V0');
            expect(await getFromHead(), ['V0']);
            expect(messages, isEmpty);
          });
        });

        group('multiple', () {
          test('when available', () async {
            await initGit(d);
            addAndCommitSampleFile(d);
            await addTags(d, ['V0', 'T0', 'T1']);
            expect(await getFromHead(), ['V0', 'T1', 'T0']);
          });

          test('but not tags of previous commits', () async {
            await initGit(d);
            await setPubspec(d, version: '1.0.0');
            commitPubspec(d);
            await addTag(d, 'T0');
            expect(await getFromHead(), ['T0']);

            // Commit a new change -> No tags should be returned
            await setPubspec(d, version: '2.0.0');
            commitPubspec(d);
            expect(await getFromHead(), isEmpty);
          });
        });
      });
    });

    group('all(....)', () {
      group('should return', () {
        test('all tags', () async {
          await initGit(d);
          addAndCommitSampleFile(d);

          // Initially we should get no tags
          expect(await getAll(), <String>[]);

          // Add a first two tags
          await addTags(d, ['0a', '0b']);
          expect(await getAll(), ['0b', '0a']);

          // Add another commit
          await updateAndCommitSampleFile(d);
          await addTags(d, ['1a', '1b']);
          expect(await getAll(), ['1b', '1a', '0b', '0a']);

          // From head should still work
          expect(await getFromHead(), ['1b', '1a']);
        });
      });
    });

    group('run()', () {
      group('with --head-only', () {
        group('should log', () {
          test('the tags of the latest revision', () async {
            await initGit(d);
            addAndCommitSampleFile(d);
            await addTags(d, ['0a', '0b']);

            await updateAndCommitSampleFile(d);
            await addTags(d, ['1a', '1b']);

            final runner = CommandRunner<void>('test', 'test');
            runner.addCommand(GetTags(log: messages.add));
            await runner
                .run(['get-tags', '--directory', d.path, '--head-only']);

            expect(messages.last.split('\n'), ['1b', '1a']);
          });
        });
      });

      group('without --head-only', () {
        group('should log', () {
          test('all historic tags', () async {
            await initGit(d);

            addAndCommitSampleFile(d);
            await addTags(d, ['0b', '0a']);

            await updateAndCommitSampleFile(d);
            await addTags(d, ['1b', '1a']);

            final runner = CommandRunner<void>('test', 'test');
            runner.addCommand(GetTags(log: messages.add));
            await runner.run(['get-tags', '--directory', d.path]);

            expect(messages.last.split('\n'), ['1b', '1a', '0b', '0a']);
          });
        });
      });
    });
  });
}
