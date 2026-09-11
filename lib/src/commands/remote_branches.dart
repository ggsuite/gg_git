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
/// Lists the short names of the remote branches at `origin` (the `origin/`
/// prefix is stripped and the symbolic `origin/HEAD` is dropped).
class RemoteBranches extends GgGitBase<List<String>> {
  /// Constructor
  RemoteBranches({required super.ggLog, super.processWrapper})
    : super(name: 'remote-branches', description: 'Lists remote branch names.');

  // ...........................................................................
  @override
  Future<List<String>> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) => get(directory: directory, ggLog: ggLog);

  // ...........................................................................
  /// Returns the remote branch short names. Throws on failure.
  @override
  Future<List<String>> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // The full ref name, not the short one: git shortens the symbolic
    // `refs/remotes/origin/HEAD` to plain `origin`, which no filter for
    // `origin/HEAD` catches — and `origin` then passed as a branch.
    final result = await processWrapper.run('git', [
      'for-each-ref',
      '--format=%(refname)',
      'refs/remotes/origin',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      throw Exception(
        'Could not list remote branches in "${dirName(directory)}": '
        '${result.stderr}.',
      );
    }

    const prefix = 'refs/remotes/origin/';
    return (result.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith(prefix))
        .map((l) => l.substring(prefix.length))
        .where((l) => l.isNotEmpty && l != 'HEAD')
        .toList();
  }
}

/// Mocktail mock
class MockRemoteBranches extends MockDirCommand<List<String>>
    implements RemoteBranches {}
