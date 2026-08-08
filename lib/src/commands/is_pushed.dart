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
    Map<String, dynamic> options = const {},
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
    //
    // »--porcelain=v2« is never translated and never reformatted, in contrast
    // to the prose of a plain »git status«, which depends on the user's locale
    // and on the git version.
    final result = await processWrapper.run('git', [
      'status',
      '--porcelain=v2',
      '--branch',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      throw Exception('Could not run "git push" in "${dirName(directory)}".');
    }

    final lines = (result.stdout as String).split('\n');
    final status = _StatusV2.fromLines(lines);

    if (status.ahead > 0) {
      ggLog('The local branch is ahead of remote branch.');
      return false;
    }

    if (status.behind > 0) {
      ggLog('Local branch is behind remote branch.');
      return false;
    }

    if (status.hasUntrackedFiles) {
      ggLog('There are untracked files.');
      return ignoreUnCommittedChanges;
    }

    if (status.hasStagedChanges) {
      ggLog('There are staged but uncommitted changes.');
      return ignoreUnCommittedChanges;
    }

    if (status.hasUnstagedChanges) {
      ggLog('There are not-added files.');
      return ignoreUnCommittedChanges;
    }

    // »# branch.ab« is only written when the branch has an upstream branch.
    if (!status.hasUpstream) {
      ggLog('The branch has no remote.');
      return false;
    }

    ggLog('Everything is pushed.');
    return true;
  }

  // ...........................................................................
  final UpstreamBranch _upstreamBranch;
}

// #############################################################################
/// The parsed output of »git status --porcelain=v2 --branch«.
class _StatusV2 {
  _StatusV2({
    required this.hasUpstream,
    required this.ahead,
    required this.behind,
    required this.hasStagedChanges,
    required this.hasUnstagedChanges,
    required this.hasUntrackedFiles,
  });

  /// Parses the lines of »git status --porcelain=v2 --branch«.
  factory _StatusV2.fromLines(List<String> lines) {
    var hasUpstream = false;
    var ahead = 0;
    var behind = 0;
    var hasStagedChanges = false;
    var hasUnstagedChanges = false;
    var hasUntrackedFiles = false;

    for (final line in lines) {
      // »# branch.ab +<ahead> -<behind>«
      if (line.startsWith('# branch.ab ')) {
        hasUpstream = true;
        final parts = line.substring('# branch.ab '.length).split(' ');
        ahead = int.parse(parts[0].replaceFirst('+', ''));
        behind = int.parse(parts[1].replaceFirst('-', ''));
        continue;
      }

      // »? <path>«
      if (line.startsWith('? ')) {
        hasUntrackedFiles = true;
        continue;
      }

      // »u <XY> ...« - unmerged, i.e. conflicting, files
      if (line.startsWith('u ')) {
        hasUnstagedChanges = true;
        continue;
      }

      // »1 <XY> ...« - changed, »2 <XY> ...« - renamed or copied
      if (line.startsWith('1 ') || line.startsWith('2 ')) {
        final xy = line.substring(2, 4);
        hasStagedChanges = hasStagedChanges || xy[0] != '.';
        hasUnstagedChanges = hasUnstagedChanges || xy[1] != '.';
      }
    }

    return _StatusV2(
      hasUpstream: hasUpstream,
      ahead: ahead,
      behind: behind,
      hasStagedChanges: hasStagedChanges,
      hasUnstagedChanges: hasUnstagedChanges,
      hasUntrackedFiles: hasUntrackedFiles,
    );
  }

  /// True when the branch has an upstream branch.
  final bool hasUpstream;

  /// The number of commits the local branch is ahead of the remote branch.
  final int ahead;

  /// The number of commits the local branch is behind the remote branch.
  final int behind;

  /// True when there are staged but uncommitted changes.
  final bool hasStagedChanges;

  /// True when there are changes that are not staged.
  final bool hasUnstagedChanges;

  /// True when there are untracked files.
  final bool hasUntrackedFiles;
}

/// Mocktail mock
class MockIsPushed extends MockDirCommand<bool> implements IsPushed {}
