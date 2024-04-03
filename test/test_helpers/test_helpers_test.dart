// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('TestHelpers', () {
    test('should work fine', () async {
      // const TestHelpers();
      final testDir = await initTestDir();
      expect(await testDir.exists(), isTrue);
      testDir.deleteSync(recursive: true);
    });
  });

  group('addAndCommitGitIgnoreFile()', () {
    test('should work fine', () async {
      final testDir = await initTestDir();
      await initGit(testDir);
      final gitIgnoreFile = File('${testDir.path}/.gitignore');
      expect(await gitIgnoreFile.exists(), isFalse);
      await addAndCommitGitIgnoreFile(testDir, content: 'test\n');
      expect(await gitIgnoreFile.exists(), isTrue);
      testDir.deleteSync(recursive: true);
    });

    group('revertLocalChanges(directory)', () {
      test('should revert all local changes', () async {
        // Create a git repo
        final testDir = Directory.systemTemp.createTempSync('test');
        await initGit(testDir);

        // Create an initial commit
        await addAndCommitSampleFile(testDir);
        final contentBefore =
            File('${testDir.path}/$sampleFileName').readAsStringSync();

        // Make a change
        await updateSampleFileWithoutCommitting(testDir);
        final contentAfter =
            File('${testDir.path}/$sampleFileName').readAsStringSync();
        expect(contentBefore, isNot(contentAfter));

        // Revert all changes
        await revertLocalChanges(testDir);
        final contentReverted =
            File('${testDir.path}/$sampleFileName').readAsStringSync();
        expect(contentBefore, contentReverted);
      });
    });

    group('initLocalAndRemoteGit()', () {
      test('should create and connect a local and remote git repo', () async {
        final (dLocal, _) = await initLocalAndRemoteGit();
        await addAndCommitSampleFile(dLocal);
        await pushLocalChanges(dLocal);
      });
    });
  });
}
