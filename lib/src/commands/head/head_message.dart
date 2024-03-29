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
          name: 'message',
          description: 'Returns the commit message of the head revision.',
        ) {
    _addParams();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    int? offset,
  }) async {
    offset = HeadHash.readOffset(offset, argResults);

    final result = await get(
      directory: directory,
      ggLog: ggLog,
      offset: offset,
    );
    ggLog(result);
  }

  // ...........................................................................
  /// Returns the commit message of the head revision in the given directory.
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
    int offset = 0,
  }) async {
    HeadHash.checkOffset(offset);

    await check(directory: directory);

    final isCommited =
        await _isCommitted.get(directory: directory, ggLog: ggLog);

    if (!isCommited) {
      throw Exception('Not everything is commited.');
    }

    // To get the commit message, the command is adjusted to use `git log`
    final offsetString = offset == 0 ? '' : '~$offset';
    final result = await processWrapper.run(
      'git',
      ['log', '-1', '--pretty=format:%B', 'HEAD$offsetString'],
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
      'offset',
      abbr: 'o',
      help: 'E.g. 1 to get one commit before the head hash.',
      mandatory: false,
    );
  }
}

/// Mocktail mock
class MockHeadMessage extends Mock implements HeadMessage {}
