// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_git/src/base/git_retry.dart';
import 'package:gg_git/src/base/git_version.dart';
import 'package:gg_git/src/base/ssh_host_keys.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Runs `git fetch` in the given directory.
class Fetch extends GgGitBase<void> {
  /// Constructor
  Fetch({
    required super.ggLog,
    super.processWrapper,
    this._gitRetry = const GitRetry(),
    this._gitVersion = const GitVersion(),
  }) : super(name: 'fetch', description: 'Runs "git fetch".');

  // ...........................................................................
  /// The `git fetch` options that make the tags of a checkout a copy of the
  /// tags of its remote: a tag deleted there is deleted (`--prune-tags`), a
  /// tag moved there is moved (`--force`), and the remote-tracking branches
  /// are pruned with them — one connection, where deleting the local tags
  /// and fetching them anew takes three.
  static const List<String> mirrorTagsOptions = <String>[
    '--prune',
    '--prune-tags',
    '--force',
  ];

  /// The git configuration that makes a fetch from `origin` update
  /// `origin/HEAD` to the branch the remote declares as its default — in
  /// the connection of the fetch, where `git remote set-head origin --auto`
  /// opens a second one. Understood from [GitVersion.followRemoteHead] on.
  static const List<String> followRemoteHeadConfig = <String>[
    '-c',
    'remote.origin.followRemoteHEAD=always',
  ];

  /// The arguments of `git` for a fetch with the given options, see [get].
  static List<String> arguments({
    bool mirrorTags = false,
    bool followRemoteHead = false,
  }) => <String>[
    if (followRemoteHead) ...followRemoteHeadConfig,
    'fetch',
    if (mirrorTags) ...mirrorTagsOptions,
  ];

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) => get(directory: directory, ggLog: ggLog);

  // ...........................................................................
  /// Fetches from the remote. Throws on failure; when ssh is not set up for
  /// the host of `origin`, the error says what to do next.
  ///
  /// With [mirrorTags] the tags of the checkout become a copy of the
  /// remote's, see [mirrorTagsOptions].
  ///
  /// With [refreshDefaultBranch] `origin/HEAD` names the default branch of
  /// the remote afterwards — a plain fetch leaves it as the clone recorded
  /// it, also after the default branch was renamed on the server. A git that
  /// can do so updates it while it fetches ([followRemoteHeadConfig]); an
  /// older one is asked with `git remote set-head origin --auto` afterwards,
  /// whose failure never fails the fetch: the fetch reached the remote, and
  /// a remote that cannot answer this leaves things as they are.
  @override
  Future<void> get({
    required GgLog ggLog,
    required Directory directory,
    bool mirrorTags = false,
    bool refreshDefaultBranch = false,
  }) async {
    final (major, minor) = GitVersion.followRemoteHead;
    final followRemoteHead =
        refreshDefaultBranch && await _gitVersion.isAtLeast(major, minor);
    final args = arguments(
      mirrorTags: mirrorTags,
      followRemoteHead: followRemoteHead,
    );

    final result = await _gitRetry.run(
      () => processWrapper.run('git', args, workingDirectory: directory.path),
      ggLog: ggLog,
      description: 'git fetch',
    );

    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      final out = (result.stdout as String).trim();
      final detail = err.isNotEmpty ? err : out;
      final failure = 'Could not fetch in "${dirName(directory)}": $detail.';
      if (!SshHostKeys.isSetupProblem(err)) {
        throw Exception(failure);
      }
      final hint = SshHostKeys.setupHint(await _originUrl(directory), err);
      throw Exception('$failure\n$hint');
    }

    if (refreshDefaultBranch && !followRemoteHead) {
      await _gitRetry.run(
        () => processWrapper.run('git', const [
          'remote',
          'set-head',
          'origin',
          '--auto',
        ], workingDirectory: directory.path),
        ggLog: ggLog,
        description: 'git remote set-head origin --auto',
      );
    }
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  /// The url of `origin`, which the hint names in its commands.
  Future<String> _originUrl(Directory directory) async {
    final result = await processWrapper.run('git', [
      'remote',
      'get-url',
      'origin',
    ], workingDirectory: directory.path);
    return (result.stdout as String).trim();
  }

  // ...........................................................................
  final GitRetry _gitRetry;
  final GitVersion _gitVersion;
}

/// Mocktail mock
class MockFetch extends MockDirCommand<void> implements Fetch {}
