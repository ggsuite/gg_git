// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

// #############################################################################
/// Checks if eyerything in the current working directory is committed.
class Commit extends GgGitBase<void> {
  /// Constructor
  Commit({
    required super.ggLog,
    super.processWrapper,
    super.name = 'commit',
    super.description = 'Commits everything in a given directory.',
    ModifiedFiles? modifiedFiles,
    IsPushed? isPushed,
  })  : _modifiedFiles = modifiedFiles ?? ModifiedFiles(ggLog: ggLog),
        _isPushed = isPushed ?? IsPushed(ggLog: ggLog) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final stage = argResults!['stage'] as bool;
    final message = argResults!['message'] as String;
    final ammend = argResults!['ammend'] as bool;
    final ammendWhenNotPushed = argResults!['ammend-when-not-pushed'] as bool;

    await commit(
      directory: directory,
      message: message,
      doStage: stage,
      ggLog: ggLog,
      ammend: ammend,
      ammendWhenNotPushed: ammendWhenNotPushed,
    );
  }

  // ...........................................................................
  /// Returns true if everything in the directory is committed.
  Future<void> commit({
    required GgLog ggLog,
    required Directory directory,
    required bool doStage,
    required String message,
    bool ammend = false,
    bool ammendWhenNotPushed = false,
  }) async {
    await check(directory: directory);

    await _commit(
      directory: directory,
      message: message,
      doStage: doStage,
      ammend: ammend,
      ammendWhenNotPushed: ammendWhenNotPushed,
    );
  }

  // ######################
  // Private
  // ######################

  final ModifiedFiles _modifiedFiles;
  final IsPushed _isPushed;

  // ...........................................................................
  Future<void> _checkModifiedFiles(Directory directory, GgLog ggLog) async {
    final files = await _modifiedFiles.get(directory: directory, ggLog: ggLog);
    if (files.isEmpty) {
      throw Exception('Nothing to commit. No uncommmited changes.');
    }
  }

  // ...........................................................................
  Future<void> _commit({
    required Directory directory,
    required String message,
    required bool doStage,
    required bool ammend,
    required bool ammendWhenNotPushed,
  }) async {
    await _checkModifiedFiles(directory, ggLog);

    if (ammendWhenNotPushed && ammend) {
      throw Exception(
        'You cannot use --ammend and --ammend-when-not-pushed '
        'at the same time.',
      );
    }

    if (doStage) {
      await _stage(directory);
    }

    ammend = ammend ||
        ammendWhenNotPushed &&
            !await _isPushed.get(
              directory: directory,
              ggLog: ggLog,
              ignoreUnCommittedChanges: true,
            );

    final result = await processWrapper.run(
      'git',
      ['commit', '-m', message, if (ammend) '--amend'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      var message = 'Could not commit files: ';
      if (result.stderr?.isNotEmpty == true) {
        message += result.stderr.toString();
      }

      if (result.stdout?.isNotEmpty == true) {
        message += result.stdout.toString();
      }

      throw Exception(message);
    }
  }

// .............................................................................
  Future<void> _stage(
    Directory directory,
  ) async {
    final result = await processWrapper.run(
      'git',
      ['add', '.'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not stage files: ${result.stderr}');
    }
  }

  // ...........................................................................
  void _addArgs() {
    argParser
      ..addFlag(
        'stage',
        abbr: 's',
        help: 'Stage all files before committing.',
        defaultsTo: false,
      )
      ..addOption(
        'message',
        abbr: 'm',
        help: 'The commit message.',
        mandatory: true,
      )
      ..addFlag(
        'ammend',
        abbr: 'a',
        help: 'Ammend the commit to the previous one.',
        defaultsTo: false,
      )
      ..addFlag(
        'ammend-when-not-pushed',
        abbr: 'w',
        help: 'Ammend the commit when the last commit is not yet pushed.',
        defaultsTo: false,
      );
  }
}

/// Mocktail mock
class MockCommit extends mocktail.Mock implements Commit {}
