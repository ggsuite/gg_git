// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

/// Returns a 64bit hash summarizing the changes since the last commit.
class LastChangesHash extends GgGitBase<void> {
  // ...........................................................................
  /// Constructor
  LastChangesHash({
    required super.ggLog,
    super.processWrapper,
    super.name = 'last-changes-hash',
    super.description =
        'Returns a 64bit hash summarizing the changes since the last commit.',
    ModifiedFiles? modifiedFiles,
    HeadHash? headHash,
    IsCommitted? isCommitted,
  })  : _modifiedFiles = modifiedFiles ?? ModifiedFiles(ggLog: ggLog),
        _headHash = headHash ?? HeadHash(ggLog: ggLog),
        _isCommitted = isCommitted ?? IsCommitted(ggLog: ggLog);

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final result = await get(
      directory: directory,
      ggLog: ggLog,
    );
    ggLog(result.toString());
  }

  // ...........................................................................
  /// Returns the modified files in the current git repository.
  Future<int> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Get the list of modified files
    final modifiedFiles = (await _modifiedFiles.get(
      ggLog: ggLog,
      directory: directory,
      force: true,
    ))
      ..sort();

    // Is everything committed?
    final isCommitted = await _isCommitted.get(
      ggLog: ggLog,
      directory: directory,
    );

    // Get the last commit hash
    final lastHash = await _headHash.get(
      ggLog: ggLog,
      directory: directory,
      force: true,
      offset: isCommitted ? 1 : 0,
    );

    // Calculate the hash
    final hash = modifiedFiles.fold<int>(
      lastHash.hashCode,
      (int previousValue, element) => previousValue ^ element.hashCode,
    );

    return hash;
  }

  final ModifiedFiles _modifiedFiles;
  final HeadHash _headHash;
  final IsCommitted _isCommitted;
}

/// Mocktail mock
class MockChangeHash extends Mock implements LastChangesHash {}
