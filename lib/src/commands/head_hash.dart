// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

// #############################################################################
/// Returns the commit hash of the head revision.
class HeadHash extends GgGitBase<void> {
  /// Constructor
  HeadHash({
    required super.log,
    super.processWrapper,
    IsCommitted? isCommitted,
  })  : _isCommitted = isCommitted ??
            IsCommitted(
              log: log,
              processWrapper: processWrapper,
            ),
        super(
          name: 'head-hash',
          description: 'Returns the commit hash of the head revision.',
        );

  // ...........................................................................
  @override
  Future<void> run({Directory? directory}) async {
    final inputDir = dir(directory);

    final result = await get(directory: inputDir);
    log(result);
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<String> get({
    void Function(String)? log,
    required Directory directory,
  }) async {
    log ??= this.log;

    // Directory is a git repo?
    await check(directory: directory);

    // Everything is commited?
    final isCommited = await _isCommitted.get(directory: directory, log: log);

    if (!isCommited) {
      throw Exception('Not everything is commited.');
    }

    // Read the hash
    final result = await processWrapper.run(
      'git',
      ['rev-parse', 'HEAD'],
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    } else {
      throw Exception('Could not read the head hash: ${result.stderr}');
    }
  }

  // ...........................................................................
  final IsCommitted _isCommitted;
}

/// Mocktail mock
class MockHeadHash extends mocktail.Mock implements HeadHash {}
