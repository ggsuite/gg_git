// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';

/// Returns true when the current branch is neither main nor master.
class IsFeatureBranch extends GgGitBase<bool> {
  /// Constructor
  IsFeatureBranch({
    required super.ggLog,
    super.processWrapper,
    LocalBranch? localBranch,
  }) : _localBranch = localBranch ?? LocalBranch(ggLog: ggLog),
       super(
         name: 'is-feature-branch',
         description:
             'Returns true when the current branch is neither main nor master.',
       );

  /// Command used to resolve the current local branch.
  final LocalBranch _localBranch;

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result.toString());
    return result;
  }

  // ...........................................................................
  /// Returns true when the current branch is neither main nor master.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    final branchName = await _localBranch.get(
      directory: directory,
      ggLog: ggLog,
    );

    if (branchName.isEmpty) {
      // Detached HEAD or no branch name available -> treat as non-feature.
      return false;
    }

    final lower = branchName.toLowerCase();
    return lower != 'main' && lower != 'master';
  }
}

/// Mocktail mock
class MockIsFeatureBranch extends MockDirCommand<bool>
    implements IsFeatureBranch {}
