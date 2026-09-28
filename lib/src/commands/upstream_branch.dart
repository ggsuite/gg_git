// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Provides "ggGit pushed dir" command
class UpstreamBranch extends GgGitBase<String> {
  /// Constructor
  UpstreamBranch({required super.ggLog, super.processWrapper})
    : super(
        name: 'upstream-branch',
        description:
            'Returns the remote branch assigned to the current branch.',
      );

  // ...........................................................................
  @override
  Future<String> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final messages = <String>[];

    final result = await get(ggLog: messages.add, directory: directory);
    if (result.isNotEmpty) {
      ggLog(result);
    }

    return result;
  }

  // ...........................................................................
  /// Returns the remote branch or an empty string if no upstream is set.
  ///
  /// A configured upstream whose remote-tracking ref is gone counts as no
  /// upstream too: the remote branch was merged and deleted (e.g. by an
  /// auto-completed pull request) and a later fetch pruned the ref. There is
  /// nothing left to compare with, and the next push sets a new upstream.
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Is everything pushed?
    final result = await processWrapper.run('git', [
      'rev-parse',
      '--abbrev-ref',
      '--symbolic-full-name',
      '@{u}',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      final error = result.stderr.toString();
      if (_noUpstreamMarkers.any(error.contains)) {
        return '';
      }
      throw Exception(
        'Could not run "git rev-parse" in "${dirName(directory)}": '
        '${result.stderr.toString()}.',
      );
    } else {
      return result.stdout.toString().trim();
    }
  }

  // ######################
  // Private
  // ######################

  /// Stderr fragments of »git rev-parse @{u}« that mean »no usable upstream«.
  static const _noUpstreamMarkers = [
    'no upstream configured',
    'no such branch',
    'HEAD does not point to a branch',
    // The upstream is configured, but its remote-tracking ref is gone.
    "ambiguous argument '@{u}'",
    'not stored as a remote-tracking branch',
  ];
}

/// Mocktail mock
class MockUpstreamBranch extends MockDirCommand<String>
    implements UpstreamBranch {}
