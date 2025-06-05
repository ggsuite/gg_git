// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

// #############################################################################
/// Provides "ggGit pushed dir" command
class IsPushed extends GgGitBase<bool> {
  /// Constructor
  IsPushed({
    required super.ggLog,
    super.processWrapper,
    UpstreamBranch? upstreamBranch,
  }) : _upstreamBranch = upstreamBranch ?? UpstreamBranch(ggLog: ggLog),
       super(
         name: 'is-pushed',
         description: 'Is everything in the current working directory pushed?',
       );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is pushed.',
      ggLog: ggLog,
    );

    final result = await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );

    if (!result) {
      throw Exception(brightBlack(messages.join('\n')));
    }

    return result;
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  @override
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
    bool ignoreUnCommittedChanges = false,
  }) async {
    // Does branch have an upstream branch?
    final upstreamBranch = await _upstreamBranch.get(
      ggLog: ggLog,
      directory: directory,
    );
    if (upstreamBranch.isEmpty) {
      return false;
    }

    // Is everything pushed?
    final result = await processWrapper.run('git', [
      'status',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      throw Exception('Could not run "git push" in "${dirName(directory)}".');
    }

    final stdout = result.stdout as String;

    if (stdout.contains('Your branch is ahead')) {
      ggLog('The local branch is ahead of remote branch.');
      return false;
    } else if (stdout.contains('Your branch is behind')) {
      ggLog('Local branch is behind remote branch.');
      return false;
    } else if (stdout.contains('Untracked files')) {
      ggLog('There are untracked files.');
      return ignoreUnCommittedChanges || false;
    } else if (stdout.contains('Changes to be committed')) {
      ggLog('There are staged but uncommitted changes.');
      return ignoreUnCommittedChanges || false;
    } else if (stdout.contains('Changes not staged for commit')) {
      ggLog('There are not-added files.');
      return ignoreUnCommittedChanges || false;
    } else if (stdout.contains('Your branch is up to date')) {
      ggLog('Everything is pushed.');
      return true;
    } else if (stdout.contains('nothing to commit, working tree clean')) {
      ggLog('The branch has no remote.');
      return false;
    }

    throw Exception('Unknown status of "git push" in "${dirName(directory)}".');
  }

  // ...........................................................................
  final UpstreamBranch _upstreamBranch;
}

/// Mocktail mock
class MockIsPushed extends MockDirCommand<bool> implements IsPushed {}
