// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_log/gg_log.dart';

/// Returns the name of the repository's default branch.
///
/// The default branch is what the remote declares as `origin/HEAD` — the
/// branch a clone checks out, the one pull requests target. It is read
/// **offline** from `refs/remotes/origin/HEAD`, which `git clone` records
/// and `git remote set-head origin --auto` refreshes; no network is touched.
///
/// A recorded `origin/HEAD` that points at a branch the remote no longer
/// has — e.g. a stale `origin/develop` after the repository moved to `main`
/// — is ignored. Without a usable `origin/HEAD` the branch is guessed the
/// way it always was: `main` when a local or remote `main` exists, else
/// `master`. An empty string means the repository has no default branch at
/// all.
class DefaultBranch extends GgGitBase<String> {
  /// Constructor
  DefaultBranch({required super.ggLog, super.processWrapper})
    : super(
        name: 'default-branch',
        description: 'Returns the name of the default branch.',
      );

  // ...........................................................................
  @override
  Future<String> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result);
    return result;
  }

  // ...........................................................................
  /// Returns the default branch name, or an empty string when there is none.
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final declared = await declaredDefaultBranch(directory: directory);
    if (declared != null) {
      return declared;
    }

    for (final candidate in fallbackCandidates) {
      if (await _branchExists(directory, candidate)) {
        return candidate;
      }
    }

    return '';
  }

  /// The names tried, in order, when the remote declares no default branch.
  static const List<String> fallbackCandidates = ['main', 'master'];

  // ...........................................................................
  /// The branch the remote declares as its default — what
  /// `refs/remotes/origin/HEAD` points at — or null when nothing is declared
  /// or the declared branch does not exist on the remote anymore.
  ///
  /// Unlike [get] this never guesses: a null answer means the repository
  /// itself does not say which branch is the default one.
  Future<String?> declaredDefaultBranch({required Directory directory}) async {
    final result = await processWrapper.run('git', [
      'symbolic-ref',
      '--quiet',
      '--short',
      'refs/remotes/origin/HEAD',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      return null;
    }

    // `--short` yields `origin/<branch>`.
    final target = result.stdout.toString().trim();
    const prefix = 'origin/';
    final name = target.startsWith(prefix)
        ? target.substring(prefix.length)
        : target;

    if (name.isEmpty ||
        !await _refExists(directory, 'refs/remotes/origin/$name')) {
      return null;
    }

    return name;
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  /// True when [branch] exists locally or on origin.
  Future<bool> _branchExists(Directory directory, String branch) async =>
      await _refExists(directory, 'refs/heads/$branch') ||
      await _refExists(directory, 'refs/remotes/origin/$branch');

  // ...........................................................................
  Future<bool> _refExists(Directory directory, String ref) async {
    final result = await processWrapper.run('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      ref,
    ], workingDirectory: directory.path);
    return result.exitCode == 0;
  }
}

/// Mocktail mock
class MockDefaultBranch extends MockDirCommand<String>
    implements DefaultBranch {}
