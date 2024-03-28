// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

// #############################################################################
/// Returns the commit hash of the head revision.
class HeadHash extends GgGitBase<void> {
  /// Constructor
  HeadHash({
    required super.ggLog,
    super.processWrapper,
    IsCommitted? isCommitted,
  })  : _isCommitted = isCommitted ??
            IsCommitted(
              ggLog: ggLog,
              processWrapper: processWrapper,
            ),
        super(
          name: 'head-hash',
          description: 'Returns the commit hash of the head revision.',
        ) {
    _addParams();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    String? generation,
  }) async {
    final result = await get(
      directory: directory,
      ggLog: ggLog,
      generation: generation ?? argResults?['generation'] as String? ?? '',
    );
    ggLog(result);
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
    String generation = '',
  }) async {
    _checkGeneration(generation);

    // Directory is a git repo?
    await check(directory: directory);

    // Everything is commited?
    final isCommited =
        await _isCommitted.get(directory: directory, ggLog: ggLog);

    if (!isCommited) {
      throw Exception('Not everything is commited.');
    }

    // Read the hash
    final result = await processWrapper.run(
      'git',
      ['rev-parse', 'HEAD$generation'],
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

  // ...........................................................................
  void _addParams() {
    argParser.addOption(
      'generation',
      abbr: 'g',
      help: 'E.g. ~1 to get one commit before the head hash.',
      mandatory: false,
    );
  }

  // ...........................................................................
  void _checkGeneration(String generation) {
    if (generation.isNotEmpty) {
      if (!RegExp(r'^~\d+$').hasMatch(generation)) {
        throw Exception(
          'Invalid generation reference: $generation. '
          'Correct example: "~1"',
        );
      }
    }
  }
}

/// Mocktail mock
class MockHeadHash extends mocktail.Mock implements HeadHash {}
