// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

/// Reads the commit message of the head revision.
class HeadMessage extends GgGitBase<void> {
  // ...........................................................................
  /// Constructor
  HeadMessage({
    required super.ggLog,
    super.processWrapper,
    IsCommitted? isCommitted,
  })  : _isCommitted = isCommitted ??
            IsCommitted(
              ggLog: ggLog,
              processWrapper: processWrapper,
            ),
        super(
          name: 'head-message',
          description: 'Returns the commit message of the head revision.',
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
  /// Returns the commit message of the head revision in the given directory.
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
    String generation = '',
  }) async {
    _checkGeneration(generation);

    await check(directory: directory);

    final isCommited =
        await _isCommitted.get(directory: directory, ggLog: ggLog);

    if (!isCommited) {
      throw Exception('Not everything is commited.');
    }

    // To get the commit message, the command is adjusted to use `git log`
    final result = await processWrapper.run(
      'git',
      ['log', '-1', '--pretty=format:%B', 'HEAD$generation'],
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    } else {
      throw Exception('Could not read the head message: ${result.stderr}');
    }
  }

  // ######################
  // Private
  // ######################

  final IsCommitted _isCommitted;

  // ...........................................................................
  void _addParams() {
    argParser.addOption(
      'generation',
      abbr: 'g',
      help: 'E.g. ~1 to get the commit message one commit before the head.',
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
class MockHeadMessage extends Mock implements HeadMessage {}
