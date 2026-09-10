// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';

/// Returns true when the current branch is not the default branch.
///
/// The default branch is what the repository declares — see
/// [DefaultBranch.declaredDefaultBranch] — not a hardcoded `main`: a
/// repository whose default branch is `develop` is not on a feature branch
/// while it sits on `develop`, and *is* on one while it sits on `main`.
/// A repository that declares nothing is judged as it always was: neither
/// `main` nor `master` is a feature branch.
class IsFeatureBranch extends GgGitBase<bool> {
  /// Constructor
  IsFeatureBranch({
    required super.ggLog,
    super.processWrapper,
    LocalBranch? localBranch,
    DefaultBranch? defaultBranch,
  }) : _localBranch = localBranch ?? LocalBranch(ggLog: ggLog),
       _defaultBranch =
           defaultBranch ??
           DefaultBranch(ggLog: ggLog, processWrapper: processWrapper),
       super(
         name: 'is-feature-branch',
         description:
             'Returns true when the current branch is not the default branch.',
       );

  /// Command used to resolve the current local branch.
  final LocalBranch _localBranch;

  /// Command used to resolve the default branch.
  final DefaultBranch _defaultBranch;

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result.toString());
    return result;
  }

  // ...........................................................................
  /// Returns true when the current branch is not the default branch.
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
    final declared = await _defaultBranch.declaredDefaultBranch(
      directory: directory,
    );

    if (declared != null) {
      return lower != declared.toLowerCase();
    }

    return !DefaultBranch.fallbackCandidates.contains(lower);
  }
}

/// Mocktail mock
class MockIsFeatureBranch extends MockDirCommand<bool>
    implements IsFeatureBranch {}
