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
class ModifiedFiles extends GgGitBase<void> {
  // ...........................................................................
  /// Constructor
  ModifiedFiles({
    required super.ggLog,
    super.processWrapper,
    super.name = 'modified-files',
    super.description = 'Returns the list of modified files.',
  });

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
    ggLog(result.join('\n'));
  }

  // ...........................................................................
  /// Returns the commit message of the head revision in the given directory.
  Future<List<String>> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Check if the directory is a Git repository
    await check(directory: directory);

    // Use git status -s to get the status in a short format
    final result = await processWrapper.run(
      'git',
      ['status', '-s'],
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      // Process the output to extract modified file names
      List<String> modifiedFiles = result.stdout
          .toString()
          .trim()
          .split('\n')
          .where((line) => line.isNotEmpty) // Filter out any empty lines
          .map((line) {
        // Each line has the format "<status> <file>", so we split by spaces
        // and get the last element, which is the file name
        var parts = line.trim().split(RegExp(r'\s+'));
        return parts.last;
      }).toList();
      return modifiedFiles;
    } else {
      // Handle the error case where the git command fails
      throw Exception('Could not retrieve modified files: ${result.stderr}');
    }
  }
}

/// Mocktail mock
class MockModifiedFiles extends Mock implements ModifiedFiles {}
