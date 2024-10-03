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
/// Provides "ggGit pushed <dir>" command
class UpstreamBranch extends GgGitBase<String> {
  /// Constructor
  UpstreamBranch({
    required super.ggLog,
    super.processWrapper,
  }) : super(
          name: 'upstream-branch',
          description:
              'Returns the remote branch assigned to the current branch.',
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
  /// Returns the remote branch or an empty string if no upstream is set.
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Is everything pushed?
    final result = await processWrapper.run(
      'git',
      ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
      workingDirectory: directory.path,
    );

    if (result.exitCode != 0) {
      final error = result.stderr.toString();
      if (error.contains('no upstream configured') ||
          error.contains('no such branch')) {
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
}

/// Mocktail mock
class MockUpstreamBranch extends MockDirCommand<String>
    implements UpstreamBranch {}
