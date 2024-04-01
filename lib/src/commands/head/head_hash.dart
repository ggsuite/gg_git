// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/src/commands/commit_count.dart';
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
    CommitCount? commitCount,
  })  : _isCommitted = isCommitted ??
            IsCommitted(
              ggLog: ggLog,
              processWrapper: processWrapper,
            ),
        _commitCount = commitCount ?? CommitCount(ggLog: ggLog),
        super(
          name: 'hash',
          description: 'Returns the commit hash of the head revision.',
        ) {
    addParams(argParser);
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    int? offset,
    bool? force,
  }) async {
    offset = readOffset(offset, argResults);
    force = argResults?['force'] as bool? ?? force ?? false;

    final result = await get(
      directory: directory,
      ggLog: ggLog,
      offset: offset,
      force: force,
    );
    ggLog(result);
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
    int offset = 0,
    bool force = false,
  }) async {
    checkOffset(offset);

    // Directory is a git repo?
    await check(directory: directory);

    // Everything is committed?
    final isCommited =
        await _isCommitted.get(directory: directory, ggLog: ggLog);

    if (!isCommited && !force) {
      throw Exception('Not everything is committed.');
    }

    // No commits available? -> Return a default hash
    final commitCount = await _commitCount.get(
      directory: directory,
      ggLog: ggLog,
    );

    if (commitCount <= offset) {
      return initialHash;
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

  /// The inital hash returned when the repo has no commits yet.
  static const initialHash = '943a702d06f34599aee1f8da8ef9f7296031d699';

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final IsCommitted _isCommitted;
  final CommitCount _commitCount;

  // ...........................................................................
  /// Adds necessary parameters.
  static void addParams(ArgParser argParser) {
    argParser.addOption(
      'offset',
      abbr: 'o',
      help: 'E.g. 1 to get one commit before the head hash.',
      mandatory: false,
    );

    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Returns the hash of the last commit, '
          'if currently not everything is committed.',
      defaultsTo: false,
      negatable: true,
    );
  }
}

/// Mocktail mock
class MockHeadHash extends mocktail.Mock implements HeadHash {}
