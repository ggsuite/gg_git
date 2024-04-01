// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/last_changes_hash.dart';
import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late LastChangesHash lastChangesHahs;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    lastChangesHahs = LastChangesHash(ggLog: messages.add);
    await initGit(d);
  });

  tearDown(() {
    d.deleteSync(recursive: true);
  });

  group('LastChangesHash', () {
    group('get(ggLog, directory, ignoredFiles)', () {
      test(
          'should return a 64bit hash summarizing the changes '
          'since the last commit.', () async {
        await initGit(d);
        await addAndCommitSampleFile(d);

        // Let's get the first hash
        final hash0 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );
        expect(hash0, isNot(0));

        // Add some modifications
        await initUncommittedFile(
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
        await initUncommittedFile(
          d,
          fileName: 'file1.txt',
          content: 'content2',
        );

        // Whe should get a different hash
        final hash3 = await lastChangesHahs.get(
          ggLog: messages.add,
          directory: d,
        );

        expect(hash3, isNot(hash2));

        // Revert the last change
        await initUncommittedFile(
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
      });
    });

    group('exec(directory, ggLog)', () {
      test('should allow to run the command from command line', () async {
        await initGit(d);
        await addAndCommitSampleFile(d);

        final runner = CommandRunner<void>('test', 'test');
        runner.addCommand(lastChangesHahs);

        await runner.run(['last-changes-hash', '-i', d.path]);
        expect(messages.length, 1);

        final hashString = messages.first;
        final hash = int.tryParse(hashString);
        expect(hash, isNotNull);
      });
    });
  });
}
