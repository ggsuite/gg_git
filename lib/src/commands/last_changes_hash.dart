// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';

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
    ModifiedFiles? modifiedFiles,
  }) : _modifiedFiles = modifiedFiles ?? ModifiedFiles(ggLog: ggLog);

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
  }) async {
    // Get the list of modified files
    final modifiedFiles = (await _modifiedFiles.get(
      ggLog: ggLog,
      directory: directory,
      force: true,
      ignoreFiles: ignoreFiles,
      returnDeleted: true,
    )).where((element) => !ignoreFiles.contains(element)).toList()..sort();

    // Get the content of the modified files
    final modifiedFileFutures = modifiedFiles.map(
      (file) => _readFile(directory, file),
    );

    final modifiedFileContents = (await Future.wait(modifiedFileFutures));

    // Calculate the hash
    final hash = modifiedFileContents.fold<int>(
      3849023480203,
      (int previousValue, element) =>
          previousValue ^
          fastStringHash(element.replaceAll('\n', '').replaceAll('\r', '')),
    );

    return hash;
  }

  final ModifiedFiles _modifiedFiles;
}

// .............................................................................
Future<String> _readFile(Directory directory, String fileName) async {
  final file = File(join(directory.path, fileName));
  const textFormats = [
    '.txt',
    '.md',
    '.yaml',
    '.yml',
    '.json',
    '.dart',
    '.sh',
    '.bat',
    '.xml',
    '.html',
    '.css',
    '.scss',
    '.js',
  ];

  final isBinaryFile = !textFormats.contains(extension(file.path));

  return await file.exists()
      ? isBinaryFile
            ? base64Encode(await file.readAsBytes())
            : await file.readAsString()
      : '$fileName was deleted';
}

/// Mocktail mock
class MockChangeHash extends Mock implements LastChangesHash {}
