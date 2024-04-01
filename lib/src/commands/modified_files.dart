// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

/// Returns the modified files in the current Git repository.
class ModifiedFiles extends GgGitBase<void> {
  // ...........................................................................
  /// Constructor
  ModifiedFiles({
    required super.ggLog,
    super.processWrapper,
    super.name = 'modified-files',
    super.description = 'Returns the list of modified files.',
  }) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    bool? force,
  }) async {
    force = force ?? argResults?['force'] as bool? ?? true;

    final result = await get(
      directory: directory,
      ggLog: ggLog,
      force: force,
    );
    ggLog(result.join('\n'));
  }

  // ...........................................................................
  /// Returns the modified files in the current Git repository.
  Future<List<String>> get({
    required GgLog ggLog,
    required Directory directory,
    bool force = false,
  }) async {
    final result = await _getModifiedFilesSinceLastCommit(
      ggLog: ggLog,
      directory: directory,
    );

    if (result.isNotEmpty) {
      return result;
    }

    if (!await _hasCommits(directory: directory)) {
      return [];
    }

    if (!force) {
      return [];
    }

    return await _getFilesModifiedLast(
      ggLog: ggLog,
      directory: directory,
    );
  }

  // ...........................................................................
  Future<List<String>> _getModifiedFilesSinceLastCommit({
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

    return _parseResult(result);
  }

  // ...........................................................................
  Future<List<String>> _getFilesModifiedLast({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Use git status -s to get the status in a short format
    final result = await processWrapper.run(
      'git',
      ['diff', '--name-only', 'HEAD^', 'HEAD'],
      workingDirectory: directory.path,
    );

    return _parseResult(result);
  }

  // ...........................................................................
  List<String> _parseResult(ProcessResult result) {
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

  // ...........................................................................
  Future<bool> _hasCommits({required Directory directory}) async {
    final result = await processWrapper.run(
      'git',
      ['rev-list', '-n', '1', '--all'],
      workingDirectory: directory.path,
    );

    if (result.exitCode != 0) {
      throw Exception('Error while retrieving revisions: ${result.stderr}');
    }

    if (result.stdout.toString().isEmpty) {
      return false;
    } else {
      return true;
    }
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Forces to return files modified between the last two commits, '
          'when all files are currently committed.',
      defaultsTo: false,
      negatable: true,
    );
  }
}

/// Mocktail mock
class MockModifiedFiles extends Mock implements ModifiedFiles {}
