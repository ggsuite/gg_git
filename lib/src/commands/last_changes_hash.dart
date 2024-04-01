// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';

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
  }) : _modifiedFiles = modifiedFiles ?? ModifiedFiles(ggLog: ggLog);

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
  /// Returns the hash of the changes since the last commit.
  Future<int> get({
    required GgLog ggLog,
    required Directory directory,
    List<String> ignoreFiles = const [],
  }) async {
    // Get the list of modified files
    final modifiedFiles = (await _modifiedFiles.get(
      ggLog: ggLog,
      directory: directory,
      force: true,
      ignoreFiles: ignoreFiles,
    ))
        .where((element) => !ignoreFiles.contains(element))
        .toList()
      ..sort();

    // Get the content of the modified files
    final modifiedFileFutures = modifiedFiles.map(
      (file) => File(join(directory.path, file)).readAsString(),
    );

    final modifiedFileContents = await Future.wait(modifiedFileFutures);

    // Calculate the hash
    final hash = modifiedFileContents.fold<int>(
      3849023480203,
      (int previousValue, element) => previousValue ^ element.hashCode,
    );

    return hash;
  }

  final ModifiedFiles _modifiedFiles;
}

/// Mocktail mock
class MockChangeHash extends Mock implements LastChangesHash {}
