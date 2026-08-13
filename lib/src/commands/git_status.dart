// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

// #############################################################################
/// One entry of »git status --porcelain«.
class GitStatusEntry {
  /// Constructor
  const GitStatusEntry({
    required this.x,
    required this.y,
    required this.path,
    this.renamedFrom,
  });

  /// The index status — the first porcelain column.
  final String x;

  /// The working-tree status — the second porcelain column.
  final String y;

  /// The path to stage. For a rename this is the **new** name.
  final String path;

  /// The old name of a rename or copy, null otherwise.
  final String? renamedFrom;

  /// Whether the entry describes a file git does not track yet.
  bool get isUntracked => x == '?' && y == '?';

  /// Whether the entry describes a file excluded by ».gitignore«.
  bool get isIgnored => x == '!' && y == '!';

  /// Whether the entry describes an unresolved merge conflict.
  ///
  /// A conflict can never be committed automatically — the caller has to stop
  /// and let the user resolve it.
  bool get isUnmerged =>
      x == 'U' || y == 'U' || (x == 'A' && y == 'A') || (x == 'D' && y == 'D');

  /// Every path this entry touches.
  ///
  /// A rename touches two: a partial commit needs the deletion of the old
  /// path as much as the addition of the new one, so both have to be staged.
  List<String> get paths => <String>[path, ?renamedFrom];

  @override
  String toString() =>
      '$x$y $path${renamedFrom == null ? '' : ' <- $renamedFrom'}';
}

// #############################################################################
/// Returns the parsed »git status --porcelain« of a repository.
///
/// Two flags are load bearing and therefore not configurable:
/// - `--untracked-files=all`, because the default collapses an untracked
///   directory into a single »?? dir/« entry — no pathspec can be built from
///   that.
/// - `-c core.quotePath=false`, because git otherwise escapes non-ASCII paths
///   into C-style quoted strings that no longer name the file on disk.
class GitStatus extends GgGitBase<List<GitStatusEntry>> {
  /// Constructor
  GitStatus({
    required super.ggLog,
    super.processWrapper,
    super.name = 'git-status',
    super.description = 'Returns the parsed »git status --porcelain«.',
  });

  // ...........................................................................
  @override
  Future<List<GitStatusEntry>> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final result = await get(directory: directory, ggLog: ggLog);
    ggLog(result.map((e) => e.toString()).join('\n'));
    return result;
  }

  // ...........................................................................
  /// Returns the entries of »git status --porcelain« for [directory].
  ///
  /// Set [includeUntracked] to false to leave untracked files out — callers
  /// that must not sweep up build output do that.
  @override
  Future<List<GitStatusEntry>> get({
    required GgLog ggLog,
    required Directory directory,
    bool includeUntracked = true,
  }) async {
    await check(directory: directory);

    final result = await processWrapper.run('git', [
      '-c',
      'core.quotePath=false',
      'status',
      '--porcelain',
      includeUntracked ? '--untracked-files=all' : '--untracked-files=no',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      throw Exception('Could not read the git status: ${result.stderr}');
    }

    return parseGitStatus(result.stdout.toString());
  }
}

// .............................................................................
/// Parses the raw stdout of »git status --porcelain« into entries.
///
/// The status columns are positional: X at index 0, Y at index 1, the path
/// from index 3 on. The line must therefore **not** be trimmed before the
/// columns are cut — a leading space is meaningful (» M file« is a modified
/// but unstaged file).
List<GitStatusEntry> parseGitStatus(String stdout) {
  final entries = <GitStatusEntry>[];

  for (final line in stdout.split('\n')) {
    // A trailing newline yields an empty last line; short lines cannot carry
    // a path and are skipped rather than producing a bogus entry.
    if (line.length < 4) {
      continue;
    }

    final x = line[0];
    final y = line[1];
    var rest = line.substring(3);

    // Windows checkouts and some git versions terminate lines with \r.
    if (rest.endsWith('\r')) {
      rest = rest.substring(0, rest.length - 1);
    }
    if (rest.isEmpty) {
      continue;
    }

    String path = rest;
    String? renamedFrom;
    const arrow = ' -> ';
    final arrowIndex = rest.indexOf(arrow);
    if ((x == 'R' || x == 'C' || y == 'R' || y == 'C') && arrowIndex >= 0) {
      renamedFrom = rest.substring(0, arrowIndex);
      path = rest.substring(arrowIndex + arrow.length);
    }

    entries.add(
      GitStatusEntry(x: x, y: y, path: path, renamedFrom: renamedFrom),
    );
  }

  return entries;
}

/// Mocktail mock
class MockGitStatus extends Mock implements GitStatus {}
