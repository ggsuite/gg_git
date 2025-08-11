// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;

  setUp(() async {
    d = await Directory.systemTemp.createTemp('test');
    await initGit(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('TestHelpers', () {
    test('should work fine', () async {
      // const TestHelpers();
      final testDir = await initTestDir();
      expect(await testDir.exists(), isTrue);
      testDir.deleteSync(recursive: true);
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
    });

    group('revertLocalChanges(directory)', () {
      test('should revert all local changes', () async {
        // Create a git repo
        final testDir = Directory.systemTemp.createTempSync('test');
        await initGit(testDir);

        // Create an initial commit
        await addAndCommitSampleFile(testDir);
        final contentBefore = File(
          '${testDir.path}/$sampleFileName',
        ).readAsStringSync();

        // Make a change
        await updateSampleFileWithoutCommitting(testDir);
        final contentAfter = File(
          '${testDir.path}/$sampleFileName',
        ).readAsStringSync();
        expect(contentBefore, isNot(contentAfter));

        // Revert all changes
        await revertLocalChanges(testDir);
        final contentReverted = File(
          '${testDir.path}/$sampleFileName',
        ).readAsStringSync();
        expect(contentBefore, contentReverted);
      });
    });

    group('resetHard(directory)', () {
      test('should reset local branch to match remote branch', () async {
        final (dLocal, _) = await initLocalAndRemoteGit();

        // Create an initial commit
        await addAndCommitSampleFile(dLocal);
        final contentBefore = File(
          '${dLocal.path}/$sampleFileName',
        ).readAsStringSync();
        await pushLocalChanges(dLocal);

        // Make and commit a change, but do not push
        await updateAndCommitSampleFile(dLocal);
        final contentAfter = File(
          '${dLocal.path}/$sampleFileName',
        ).readAsStringSync();
        expect(contentBefore, isNot(contentAfter));

        // Make a hard reset
        await hardReset(dLocal);
        final contentReverted = File(
          '${dLocal.path}/$sampleFileName',
        ).readAsStringSync();
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

    group('addAndCommitPubspecFile(dir, version)', () {
      test('should add and commit a pubspec file', () async {
        await addAndCommitPubspecFile(d);
        final pubspecFile = File('${d.path}/pubspec.yaml');
        expect(await pubspecFile.exists(), isTrue);
        final content = pubspecFile.readAsStringSync();
        expect(content.contains('version: 1.0.0'), isTrue);
      });
    });

    group('addAndCommitVersions', () {
      test('should create a pubspec.yaml and a CHANGELOG.md file '
          'containing the version', () async {
        // Add additioanl content the first time
        await addAndCommitVersions(
          d,
          pubspec: '1.0.0',
          changeLog: '1.0.0',
          gitHead: null,
          appendToPubspec: 'publish_to: none',
        );

        var content = await File('${d.path}/pubspec.yaml').readAsString();
        int occurrences = RegExp('publish_to: none').allMatches(content).length;

        expect(occurrences, 1);

        // Add additioanl content the the second time
        await addAndCommitVersions(
          d,
          pubspec: '1.0.0',
          changeLog: '1.0.0',
          gitHead: null,
          appendToPubspec: 'publish_to: none',
        );

        // Should not be added a second time
        content = await File('${d.path}/pubspec.yaml').readAsString();
        occurrences = RegExp('publish_to: none').allMatches(content).length;

        expect(occurrences, 1);
      });
    });

    group('createBranch', () {
      test('should create a new branch', () async {
        await createBranch(d, 'testBranch');
        final result = await branchName(d);
        expect(result, 'testBranch');
      });

      test('should throw if branch could not be created', () async {
        late String error;

        try {
          await createBranch(Directory('fzudifz'), 'testBranch');
        } catch (e) {
          error = e.toString();
        }

        expect(error, contains('ProcessException'));
      });
    });

    group('enableEoLf(directory), isEolEnabled(directory)', () {
      test('enables EOL linefeed in .gitattributes', () async {
        // At the beginning EOL LF is not enabled
        expect(await isEolLfEnabled(d), isFalse);

        // Create a git attributes file
        final gitAttributesPath = join(d.path, '.gitattributes');
        final file = File(gitAttributesPath);
        await file.writeAsString('# Some content');

        // EOL LF is still not enabled
        expect(await isEolLfEnabled(d), isFalse);

        // Enable EOL LF
        await enableEolLf(d);

        // Now it is enabled
        expect(await isEolLfEnabled(d), isTrue);
      });
    });
  });
}
