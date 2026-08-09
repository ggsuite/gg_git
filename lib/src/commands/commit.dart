// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Checks if eyerything in the current working directory is committed.
class Commit extends GgGitBase<void> {
  /// Constructor
  Commit({
    required super.ggLog,
    super.processWrapper,
    super.isLocked,
    super.name = 'commit',
    super.description = 'Commits everything in a given directory.',
    ModifiedFiles? modifiedFiles,
    IsPushed? isPushed,
    HeadMessage? headMessage,
  }) : _modifiedFiles = modifiedFiles ?? ModifiedFiles(ggLog: ggLog),
       _isPushed = isPushed ?? IsPushed(ggLog: ggLog),
       _headMessage = headMessage ?? HeadMessage(ggLog: ggLog) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<void> get({required Directory directory, required GgLog ggLog}) async {
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
  ///
  /// [paths] restricts the commit to the given repo-relative paths:
  /// `git add -- <paths>` followed by `git commit -m <message> -- <paths>`.
  /// Everything else stays in the working tree.
  ///
  /// - `null` (the default) commits the whole working tree — the behavior of
  ///   every caller written before this parameter existed.
  /// - An **empty list is not the same as null**. It means »scoped to
  ///   nothing« and throws, so a caller intersecting an allowlist with a
  ///   clean tree can never accidentally sweep everything instead.
  ///
  /// Pass only paths that appear in the current `git status` — git rejects a
  /// pathspec that matches nothing.
  Future<void> commit({
    required GgLog ggLog,
    required Directory directory,
    required bool doStage,
    required String message,
    bool ammend = false,
    bool ammendWhenNotPushed = false,
    List<String>? paths,
  }) async {
    await check(directory: directory);

    await _commit(
      directory: directory,
      message: message,
      doStage: doStage,
      ammend: ammend,
      ammendWhenNotPushed: ammendWhenNotPushed,
      paths: paths,
    );
  }

  // ######################
  // Private
  // ######################

  final ModifiedFiles _modifiedFiles;
  final IsPushed _isPushed;
  final HeadMessage _headMessage;

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
    List<String>? paths,
  }) async {
    if (paths == null) {
      await _checkModifiedFiles(directory, ggLog);
    } else {
      // The caller derived the paths from the status, so an empty set means
      // there is nothing of its own to commit. Same wording as the tree-wide
      // check above — several callers tolerate this failure by matching on
      // »Nothing to commit«.
      if (paths.isEmpty) {
        throw Exception('Nothing to commit. No uncommmited changes.');
      }
      await _throwOnPartialCommitBlocked(directory);
    }

    if (ammendWhenNotPushed && ammend) {
      throw Exception(
        'You cannot use --ammend and --ammend-when-not-pushed '
        'at the same time.',
      );
    }

    if (doStage) {
      await _stage(directory, paths);
    }

    ammend =
        ammend ||
        ammendWhenNotPushed &&
            !await _isPushed.get(
              directory: directory,
              ggLog: (_) {}, // ignore-line
              ignoreUnCommittedChanges: true,
            );

    // If ammendWhenNotPushed, don't overwrite last message
    if ((ammend && ammendWhenNotPushed)) {
      message = await _headMessage.get(
        ggLog: ggLog,
        directory: directory,
        throwIfNotEverythingIsCommitted: false,
      );
    }

    // "git commit" writes the index and therefore needs the index lock.
    await waitUntilUnlocked(directory: directory);

    final result = await processWrapper.run('git', [
      'commit',
      '-m',
      message,
      if (ammend) '--amend',
      // The pathspec goes on the commit as well, not only on the »git add«:
      // without it the commit takes whatever else the index already holds.
      if (paths != null) ...['--', ...paths],
    ], workingDirectory: directory.path);
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

  // ...........................................................................
  Future<void> _stage(Directory directory, List<String>? paths) async {
    // "git add" writes the index and therefore needs the index lock.
    await waitUntilUnlocked(directory: directory);

    final result = await processWrapper.run('git', [
      'add',
      if (paths == null) '.' else ...['--', ...paths],
    ], workingDirectory: directory.path);
    if (result.exitCode != 0) {
      throw Exception('Could not stage files: ${result.stderr}');
    }
  }

  // ...........................................................................
  /// Throws when git refuses a partial commit in the current repository state.
  ///
  /// `git commit -- <pathspec>` dies with »cannot do a partial commit during a
  /// merge« while a merge, cherry-pick, revert or rebase is in progress. None
  /// of gg's bookkeeping commits runs in that state, so reaching this guard
  /// means something unexpected happened. It throws rather than silently
  /// falling back to committing everything — that fallback is exactly the
  /// data loss the pathspec exists to prevent.
  Future<void> _throwOnPartialCommitBlocked(Directory directory) async {
    final gitDirResult = await processWrapper.run('git', [
      'rev-parse',
      '--git-dir',
    ], workingDirectory: directory.path);
    if (gitDirResult.exitCode != 0) {
      return; // coverage:ignore-line — check() already proved it is a repo.
    }

    var gitDir = gitDirResult.stdout.toString().trim();
    if (!gitDir.startsWith('/')) {
      gitDir = '${directory.path}/$gitDir';
    }

    const blockers = <String, String>{
      'MERGE_HEAD': 'a merge',
      'CHERRY_PICK_HEAD': 'a cherry-pick',
      'REVERT_HEAD': 'a revert',
      'rebase-merge': 'a rebase',
      'rebase-apply': 'a rebase',
    };

    for (final entry in blockers.entries) {
      final path = '$gitDir/${entry.key}';
      if (File(path).existsSync() || Directory(path).existsSync()) {
        throw Exception(
          'Cannot write a partial commit during ${entry.value}. '
          'Finish or abort it first.',
        );
      }
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
class MockCommit extends MockDirCommand<void> implements Commit {}
