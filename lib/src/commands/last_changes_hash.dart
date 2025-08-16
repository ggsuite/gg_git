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
class LastChangesHash extends GgGitBase<int> {
  // ...........................................................................
  /// Calculates a fast int hash of a string.
  static int fastStringHash(String input) {
    int hash = 0xcbf29ce484222325;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash;
  }

  // ...........................................................................
  /// Constructor
  LastChangesHash({
    required super.ggLog,
    super.processWrapper,
    super.name = 'last-changes-hash',
    super.description =
        'Returns a 64bit hash summarizing the changes since the last commit.',
    UnstagedFiles? unstagedFiles,
    IsEolLf? convertsLineFeeds,
  }) : _unStagedFiles = unstagedFiles ?? UnstagedFiles(ggLog: ggLog),
       _convertsLineFeeds = convertsLineFeeds ?? IsEolLf(ggLog: ggLog) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<int> exec({required Directory directory, required GgLog ggLog}) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result.toString());

    return result;
  }

  // ...........................................................................
  /// Returns the hash of the changes since the last commit.
  @override
  Future<int> get({
    required GgLog ggLog,
    required Directory directory,
    List<String> ignoreFiles = const [],
    bool? logDetails,
    bool? ignoreUnstaged,
  }) async {
    logDetails ??= argResults?['verbose'] as bool? ?? false;
    ignoreUnstaged ??= argResults?['ignoreUnstaged'] as bool? ?? false;

    // Get hashes of unstaged files
    final hashesFromGitLs = await _hashesFromGitLs(
      directory: directory,
      ggLog: ggLog,
      ignoreFiles: ignoreFiles,
    );

    // Get hashes of staged files
    final hashesOfUnstagedFiles = ignoreUnstaged
        ? <String, String>{}
        : await _hashesFromUnstagedFiles(
            directory: directory,
            ggLog: ggLog,
            ignoreFiles: ignoreFiles,
          );

    // Merge hashes together
    final allHashes = {...hashesFromGitLs, ...hashesOfUnstagedFiles};

    // Remove ignore files
    for (final file in ignoreFiles) {
      allHashes.remove(file);
    }

    // Turn hashes into a list
    final list = allHashes.entries
        .map((entry) => [entry.key, entry.value])
        .toList();

    // Sort list by file name
    list.sort((a, b) => a[0].compareTo(b[0]));

    // Convert list into a string
    final string = list.map((e) => e.join(' ')).join('\n');

    if (logDetails) {
      ggLog(string);
    }

    // Calculate and return the hash
    return fastStringHash(string);
  }

  // ######################
  // Private
  // ######################
  final UnstagedFiles _unStagedFiles;
  final IsEolLf _convertsLineFeeds;

  // ...........................................................................
  Future<Map<String, String>> _hashesFromUnstagedFiles({
    required GgLog ggLog,
    required Directory directory,
    List<String> ignoreFiles = const [],
  }) async {
    await _convertsLineFeeds.throwWhenNotLf(directory: directory);

    // Get unstaged files
    final unstagedFiles = (await _unStagedFiles.get(
      ggLog: ggLog,
      directory: directory,
      ignoreFiles: ignoreFiles,
    )).where((element) => !ignoreFiles.contains(element)).toList()..sort();

    final result = <String, String>{};

    // Calculate the hashes of the unstaged files
    for (final file in unstagedFiles) {
      // git hash-object .vscode/settings.json
      final raw =
          (await processWrapper.run('git', [
                'hash-object',
                file,
              ], workingDirectory: directory.path)).stdout
              as String;

      final hash = raw.trim();

      result[file] = hash;
    }

    return result;
  }

  // ...........................................................................
  Future<Map<String, String>> _hashesFromGitLs({
    required GgLog ggLog,
    required Directory directory,
    List<String> ignoreFiles = const [],
  }) async {
    final result = <String, String>{};

    // Use git status -s to get the status in a short format
    final gitLs = await processWrapper.run('git', [
      'ls-files',
      '-s',
    ], workingDirectory: directory.path);

    (gitLs.stdout as String).trim().split('\n').forEach((e) {
      final cols = e.split(RegExp(r'\s+'));
      final hash = cols[1];
      final filePath = cols[3];
      result[filePath] = hash;
    });

    return result;
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Print details.',
      defaultsTo: false,
    );

    argParser.addFlag(
      'ignoreUnstaged',
      abbr: 'u',
      help: 'Ignore unstaged files.',
      defaultsTo: false,
    );
  }
}

/// Mocktail mock
class MockChangeHash extends Mock implements LastChangesHash {}
