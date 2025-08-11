// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

/// Returns the unstaged files in the current Git repository.
class UnstagedFiles extends GgGitBase<List<String>> {
  // ...........................................................................
  /// Constructor
  UnstagedFiles({
    required super.ggLog,
    super.processWrapper,
    super.name = 'unstaged-files',
    super.description = 'Returns the list of unstaged files.',
  });

  // ...........................................................................
  @override
  Future<List<String>> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result.join('\n'));

    return result;
  }

  // ...........................................................................
  /// Returns the unstaged files in the current Git repository.
  @override
  Future<List<String>> get({
    required GgLog ggLog,
    required Directory directory,
    bool returnDeleted = false,
    List<String> ignoreFiles = const [],
  }) async {
    final result = await _getUnstagedFiles(
      ggLog: ggLog,
      directory: directory,
      ignoreFiles: ignoreFiles,
    );

    return result;
  }

  // ...........................................................................
  Future<List<String>> _getUnstagedFiles({
    required GgLog ggLog,
    required Directory directory,
    required List<String> ignoreFiles,
  }) async {
    // Check if the directory is a Git repository
    await check(directory: directory);

    // Use git status -s to get the status in a short format
    final unstagedResult = await processWrapper.run('git', [
      'diff',
      '--name-only',
    ], workingDirectory: directory.path);
    final unstaged = _parseResult(unstagedResult, ignoreFiles);

    final untrackedResult = await processWrapper.run('git', [
      'ls-files',
      '--others',
      '--exclude-standard',
    ], workingDirectory: directory.path);
    final untracked = _parseResult(untrackedResult, ignoreFiles);

    return {...unstaged, ...untracked}.toList();
  }

  // ...........................................................................
  List<String> _parseResult(ProcessResult result, List<String> ignoreFiles) {
    if (result.exitCode == 0) {
      // Process the output to extract unstaged file names
      List<String> unstagedFiles = result.stdout
          .toString()
          .trim()
          .split('\n')
          .where((line) => line.isNotEmpty) // Filter out any empty lines
          .map((line) {
            // Each line has the format "<status> <file>", so we split by spaces
            // and get the last element, which is the file name
            var parts = line.trim().split(RegExp(r'\s+'));
            return parts.last;
          })
          .toList();
      return unstagedFiles
          .where((element) => !ignoreFiles.contains(element))
          .toList();
    } else {
      // Handle the error case where the git command fails
      throw Exception('Could not retrieve unstaged files: ${result.stderr}');
    }
  }
}

/// Mocktail mock
class MockUnstagedFiles extends Mock implements UnstagedFiles {}
