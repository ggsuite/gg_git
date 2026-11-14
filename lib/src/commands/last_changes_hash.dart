// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

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
    UnstagedFiles? unstagedFiles,
    IsEolLf? convertsLineFeeds,
  }) : _unStagedFiles = unstagedFiles ?? UnstagedFiles(ggLog: ggLog),
       _convertsLineFeeds = convertsLineFeeds ?? IsEolLf(ggLog: ggLog) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<int> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
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

    // The index and the working tree are read at the same time: neither
    // needs the other, and every git call is a process to wait for.
    final (hashesFromGitLs, hashesOfUnstagedFiles) = await waitForBoth(
      // Get hashes of staged files
      _hashesFromGitLs(
        directory: directory,
        ggLog: ggLog,
        ignoreFiles: ignoreFiles,
      ),

      // Get hashes of unstaged files
      ignoreUnstaged
          ? Future.value(<String, String>{})
          : _hashesFromUnstagedFiles(
              directory: directory,
              ggLog: ggLog,
              ignoreFiles: ignoreFiles,
            ),
    );

    // Merge hashes together
    // Remove ignore files. An entry ending with a slash names a directory
    // and covers every file below it — see [isIgnoredFile].
    final allHashes = {...hashesFromGitLs, ...hashesOfUnstagedFiles}
      ..removeWhere((file, _) => isIgnoredFile(file, ignoreFiles));

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
    final unstagedFiles =
        (await _unStagedFiles.get(
            ggLog: ggLog,
            directory: directory,
            ignoreFiles: ignoreFiles,
          )).where((element) => !isIgnoredFile(element, ignoreFiles)).toList()
          ..sort();

    // A file that was deleted, or a folder, has no content to hash: its
    // hash is empty, and git is not asked — it would stop at such a path
    // and hash none of the files after it.
    final result = <String, String>{for (final file in unstagedFiles) file: ''};
    final hashable = unstagedFiles
        .where((file) => File(join(directory.path, file)).existsSync())
        .toList();

    // Calculate the hashes of the unstaged files, many files per git call:
    // one call per file made a tree with many changes slow.
    for (final files in _chunks(hashable)) {
      final hashes = await _hashObjects(directory, files);
      for (var i = 0; i < files.length; i++) {
        result[files[i]] = hashes[i];
      }
    }

    return result;
  }

  // ...........................................................................
  /// The hash of the content of each of [files], in their order.
  Future<List<String>> _hashObjects(
    Directory directory,
    List<String> files,
  ) async {
    // git hash-object -- .vscode/settings.json README.md
    final all = await processWrapper.run('git', [
      'hash-object',
      '--',
      ...files,
    ], workingDirectory: directory.path);
    final hashes = (all.stdout as String).trim().split('\n');
    if (all.exitCode == 0 && hashes.length == files.length) {
      return hashes.map((hash) => hash.trim()).toList();
    }

    // git stopped at a file it cannot read. Ask file by file: the unreadable
    // ones get the empty hash, the others their own.
    return [
      for (final file in files)
        ((await processWrapper.run('git', [
                  'hash-object',
                  '--',
                  file,
                ], workingDirectory: directory.path)).stdout
                as String)
            .trim(),
    ];
  }

  // ...........................................................................
  /// Splits [files] into lists a command line can take.
  ///
  /// Windows limits a command line to 32767 characters, a shell on Windows
  /// to 8191; [maxCommandLineLength] stays below both.
  Iterable<List<String>> _chunks(List<String> files) sync* {
    var chunk = <String>[];
    var length = 0;
    for (final file in files) {
      if (chunk.isNotEmpty && length + file.length + 1 > maxCommandLineLength) {
        yield chunk;
        chunk = <String>[];
        length = 0;
      }
      chunk.add(file);
      length += file.length + 1;
    }
    if (chunk.isNotEmpty) {
      yield chunk;
    }
  }

  /// How many characters of file names one `git hash-object` call gets at
  /// most.
  static const int maxCommandLineLength = 6000;

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

    // An empty repository has no indexed files. Splitting the empty output
    // would yield one empty line, so bail out early.
    final stdout = (gitLs.stdout as String).trim();
    if (stdout.isEmpty) {
      return result;
    }

    stdout.split('\n').forEach((e) {
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
