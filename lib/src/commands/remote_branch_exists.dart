// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Checks whether `origin/<branch>` is resolvable in the given directory
/// (after a fetch).
class RemoteBranchExists extends GgGitBase<bool> {
  /// Constructor
  RemoteBranchExists({required super.ggLog, super.processWrapper})
    : super(
        name: 'remote-branch-exists',
        description: 'Checks whether origin/<branch> exists.',
      );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
    String? branch,
  }) => get(directory: directory, ggLog: ggLog, branch: branch);

  // ...........................................................................
  /// Returns true when `origin/<branch>` resolves. Throws on a missing name.
  @override
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
    String? branch,
  }) async {
    branch ??= _argAt(0);
    if (branch == null || branch.isEmpty) {
      throw ArgumentError('Missing branch name.');
    }

    final result = await processWrapper.run('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      'refs/remotes/origin/$branch',
    ], workingDirectory: directory.path);

    return result.exitCode == 0;
  }

  // ...........................................................................
  /// The i-th positional CLI argument, or null when absent.
  String? _argAt(int i) => argResults != null && argResults!.rest.length > i
      ? argResults!.rest[i]
      : null;
}

/// Mocktail mock
class MockRemoteBranchExists extends MockDirCommand<bool>
    implements RemoteBranchExists {}
