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
/// Checks if eyerything in the current working directory is committed.
class CommitCount extends GgGitBase<int> {
  /// Constructor
  CommitCount({required super.ggLog, super.processWrapper})
    : super(
        name: 'commit-count',
        description: 'Returns the number of commits in the current branch.',
      );

  // ...........................................................................
  @override
  Future<int> exec({required Directory directory, required GgLog ggLog}) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result.toString());
    return result;
  }

  // ...........................................................................
  /// Returns true if everything in the directory is committed.
  @override
  Future<int> get({required GgLog ggLog, required Directory directory}) async {
    await check(directory: directory);

    // Is everything committed?
    final result = await processWrapper.run('git', [
      'rev-list',
      '--all',
      '--count',
    ], workingDirectory: directory.path);
    if (result.exitCode != 0) {
      throw Exception(
        'Could not run "git rev-list --all --count" '
        'in "${dirName(directory)}": '
        '${result.stderr}',
      );
    }

    return int.parse(result.stdout.toString().trim());
  }
}

/// Mocktail mock
class MockCommitCount extends MockDirCommand<int> implements CommitCount {}
