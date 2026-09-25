// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_git/src/base/git_retry.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Runs `git fetch` in the given directory.
class Fetch extends GgGitBase<void> {
  /// Constructor
  Fetch({
    required super.ggLog,
    super.processWrapper,
    this._gitRetry = const GitRetry(),
  }) : super(name: 'fetch', description: 'Runs "git fetch".');

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) => get(directory: directory, ggLog: ggLog);

  // ...........................................................................
  /// Fetches from the remote. Throws on failure.
  @override
  Future<void> get({required GgLog ggLog, required Directory directory}) async {
    final result = await _gitRetry.run(
      () => processWrapper.run('git', [
        'fetch',
      ], workingDirectory: directory.path),
      ggLog: ggLog,
      description: 'git fetch',
    );

    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      final out = (result.stdout as String).trim();
      final detail = err.isNotEmpty ? err : out;
      throw Exception('Could not fetch in "${dirName(directory)}": $detail.');
    }
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final GitRetry _gitRetry;
}

/// Mocktail mock
class MockFetch extends MockDirCommand<void> implements Fetch {}
