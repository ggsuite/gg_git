// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/args.dart';
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
          name: 'hash',
          description: 'Returns the commit hash of the head revision.',
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
    offset = readOffset(offset, argResults);

    final result = await get(
      directory: directory,
      ggLog: ggLog,
      offset: offset,
    );
    ggLog(result);
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
    int offset = 0,
  }) async {
    checkOffset(offset);

    // Directory is a git repo?
    await check(directory: directory);

    // Everything is commited?
    final isCommited =
        await _isCommitted.get(directory: directory, ggLog: ggLog);

    if (!isCommited) {
      throw Exception('Not everything is commited.');
    }

    // Read the hash
    final head = 'HEAD${offset == 0 ? '' : '~$offset'}';

    final result = await processWrapper.run(
      'git',
      ['rev-parse', head],
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    } else {
      throw Exception('Could not read the head hash: ${result.stderr}');
    }
  }

  // ...........................................................................
  /// The message for an invalid offset.
  static String invalidOffsetMessage(String offset) =>
      'Invalid offset $offset. Offset must be a positive integer.';

  // ...........................................................................
  /// Checks if the offset is valid.
  static void checkOffset(int offset) {
    if (offset < 0) {
      throw Exception(
        invalidOffsetMessage('$offset'),
      );
    }
  }

  // ...........................................................................
  /// Reads the offset from the command line arguments.
  static int readOffset(int? override, ArgResults? argResults) {
    if (override != null) {
      return override;
    }

    final offset = argResults?['offset'] as String?;
    if (offset == null) {
      return 0;
    }

    final offsetInt = int.tryParse(offset);
    if (offsetInt == null) {
      throw Exception(
        invalidOffsetMessage(offset),
      );
    }

    return offsetInt;
  }

  // ...........................................................................
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
class MockHeadHash extends mocktail.Mock implements HeadHash {}
