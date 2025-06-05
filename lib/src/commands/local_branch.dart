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
/// Provides "ggGit pushed dir" command
class LocalBranch extends GgGitBase<String> {
  /// Constructor
  LocalBranch({required super.ggLog, super.processWrapper})
    : super(
        name: 'local-branch',
        description: 'Returns the current branch name.',
      );

  // ...........................................................................
  @override
  Future<String> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final result = await get(ggLog: messages.add, directory: directory);
    if (result.isNotEmpty) {
      ggLog(result);
    }

    return result;
  }

  // ...........................................................................
  /// Returns the remote branch or an empty string if no local is set.
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Is everything pushed?
    final result = await processWrapper.run('git', [
      'branch',
      '--show-current',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      throw Exception(
        'Could not run "git rev-parse" in "${dirName(directory)}": '
        '${result.stderr.toString()}.',
      );
    } else {
      return result.stdout.toString().trim();
    }
  }
}

/// Mocktail mock
class MockLocalBranch extends MockDirCommand<String> implements LocalBranch {}
