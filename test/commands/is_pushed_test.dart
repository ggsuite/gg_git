// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/is_pushed.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'test_helpers.dart' as h;

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsPushed ggIsPushed;
  late Directory d;
  late Directory remoteDir;
  late Directory localDir;
  late File file;

  // ...........................................................................
  void initTestDir() => d = h.initTestDir();
  void initRemoteGit() => remoteDir = h.initRemoteGit(d);
  void initLocalGit() => localDir = h.initLocalGit(d);

  // ...........................................................................
  void addRemoteToLocal() {
    // Add remote
    final result2 = Process.runSync(
      'git',
      [
        'remote',
        'add',
        'origin',
        remoteDir.path,
      ],
      workingDirectory: localDir.path,
    );

    if (result2.exitCode != 0) {
      throw Exception('Could not add remote to local git repository.');
    }

    final result3 = Process.runSync(
      'git',
      [
        'push',
        '--set-upstream',
        'origin',
        'main',
      ],
      workingDirectory: localDir.path, // HIER WEITER!!!
    );

    if (result3.exitCode != 0) {
      throw Exception('Could not set up-stream.');
    }
  }

  // ...........................................................................
  void createFile() {
    file = File('${localDir.path}/file.txt');
    file.writeAsStringSync('uncommited');
  }

  // ...........................................................................
  void addFile() {
    final result = Process.runSync(
      'git',
      ['add', basename(file.path)],
      workingDirectory: localDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not add file to local git repository.');
    }
  }

  // ...........................................................................
  void commitFile() {
    final result = Process.runSync(
      'git',
      ['commit', '-m', 'Initial commit'],
      workingDirectory: localDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not commit file to local git repository.');
    }
  }

  // ...........................................................................
  void pushFile() {
    final result = Process.runSync(
      'git',
      ['push'],
      workingDirectory: localDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not push file to remote git repository.');
    }
  }

  // ...........................................................................
  void pull() {
    final result = Process.runSync(
      'git',
      ['pull'],
      workingDirectory: localDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not pull to remote git repository.');
    }
  }

  // ...........................................................................
  void removeLastCommit() {
    final result = Process.runSync(
      'git',
      ['reset', '--hard', 'HEAD~1'],
      workingDirectory: localDir.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could remove last commit.');
    }
  }

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    ggIsPushed = IsPushed(
      log: messages.add,
      processWrapper: processWrapper ?? const GgProcessWrapper(),
    );
    runner.addCommand(ggIsPushed);
  }

  // ...........................................................................
  Future<void> expectException(String message) async {
    await expectLater(
      runner.run(['is-pushed', '--input', localDir.path]),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          'Exception: $message',
        ),
      ),
    );
  }

  // ...........................................................................
  setUp(() {
    runner = CommandRunner<void>('test', 'test');
    messages.clear();
  });

  group('GgIsPushed', () {
    // #########################################################################
    group('run(), isCommited()', () {
      // #######################################################################
      group('should throw', () {
        // .....................................................................
        test('if "git status" fails', () async {
          final failingProcessWrapper = MockGgProcessWrapper();

          initTestDir();
          initLocalGit();
          initCommand(processWrapper: failingProcessWrapper);

          when(
            () => failingProcessWrapper.run(
              any(),
              any(),
              workingDirectory: localDir.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(
              1,
              1,
              'git status failed',
              'git status failed',
            ),
          );

          await expectLater(
            runner.run(['is-pushed', '--input', localDir.path]),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Could not run "git push" in "local".',
              ),
            ),
          );
        });

        // .....................................................................
        test('if "git returns an unknown status"', () async {
          final failingProcessWrapper = MockGgProcessWrapper();

          initTestDir();
          initLocalGit();
          initCommand(processWrapper: failingProcessWrapper);

          when(
            () => failingProcessWrapper.run(
              any(),
              any(),
              workingDirectory: localDir.path,
            ),
          ).thenAnswer(
            (_) async => ProcessResult(
              1,
              0,
              'Some unknown state',
              'Some unknown state',
            ),
          );

          await expectLater(
            runner.run(['is-pushed', '--input', localDir.path]),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Unknown status of "git push" in "local".',
              ),
            ),
          );
        });

        // .....................................................................
        test('if not everything is pushed', () async {
          initTestDir();
          initLocalGit();
          initCommand();

          // Not yet added file?
          createFile();
          await expectException('There are untracked files.');

          // Not yet commited file?
          addFile();
          await expectException('There are staged but uncommited changes.');

          // Not yet pushed file?
          commitFile();
          await expectException('The branch has no remote.');

          // Add a remote
          initRemoteGit();
          addRemoteToLocal();

          // Push state
          await runner.run(['is-pushed', '--input', localDir.path]);
          expect(messages.last, 'Everything is pushed.');

          // .............
          // Make a change
          await file.writeAsString('commited');
          await expectException('There are not-added files.');

          // Not yet commited file?
          addFile();
          await expectException('There are staged but uncommited changes.');

          // Not yet pushed file?
          commitFile();
          await expectException('The local branch is ahead of remote branch.');

          // Push state
          pushFile();
          await runner.run(['is-pushed', '--input', localDir.path]);
          expect(messages.last, 'Everything is pushed.');

          // ..................
          // Remove last commit
          removeLastCommit();
          await expectException('Local branch is behind remote branch.');

          pull();
          await runner.run(['is-pushed', '--input', localDir.path]);
          expect(messages.last, 'Everything is pushed.');
        });
      });
    });

    group('should print »Everything is pushed.«', () {
      // .....................................................................
      test('when everything is pushed', () async {
        initTestDir();
        initLocalGit();
        initCommand();

        // Create a pushed file
        createFile();
        addFile();
        commitFile();

        // Add a remote
        initRemoteGit();
        addRemoteToLocal();

        // Push state
        pushFile();
        await runner.run(['is-pushed', '--input', localDir.path]);
        expect(messages.last, 'Everything is pushed.');

        // .............
        // Make a change
        await file.writeAsString('commited');
        addFile();
        commitFile();
        pushFile();
        await runner.run(['is-pushed', '--input', localDir.path]);
        expect(messages.last, 'Everything is pushed.');

        // ..................
        // Remove last commit
        removeLastCommit();
        pull();
        await runner.run(['is-pushed', '--input', localDir.path]);
        expect(messages.last, 'Everything is pushed.');
      });
    });
  });
}
