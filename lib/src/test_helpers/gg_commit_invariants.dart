// @license
// Copyright (c) 2019 - 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';

/// Throws when a commit on the default branch of [repo] carries the
/// »#gg: « prefix.
///
/// The default branch only ever receives release merges and tags — gg's
/// bookkeeping commits exist on feature branches exclusively. Integration
/// tests run this after driving a flow, so a regression that writes a gg
/// commit to main fails loudly even when it slipped past every unit test.
///
/// [branch] names the branch to inspect; when null, `main` is used and
/// `master` is the fallback. [since] limits the range to the commits after
/// the given rev — for checks against long real histories.
Future<void> expectNoGgCommitsOnMain(
  Directory repo, {
  String? branch,
  String? since,
}) async {
  final resolvedBranch = branch ?? await _defaultBranch(repo);

  final range = since == null ? resolvedBranch : '$since..$resolvedBranch';
  final result = await Process.run('git', [
    'log',
    '--format=%H%x09%s',
    range,
  ], workingDirectory: repo.path);
  if (result.exitCode != 0) {
    throw Exception(
      'Could not read the history of »$resolvedBranch«: ${result.stderr}',
    );
  }

  for (final line in result.stdout.toString().split('\n')) {
    final entry = line.trim();
    if (entry.isEmpty) {
      continue;
    }
    final tab = entry.indexOf('\t');
    final hash = tab < 0 ? entry : entry.substring(0, tab);
    final subject = tab < 0 ? '' : entry.substring(tab + 1);

    if (isGgGenerated(subject)) {
      throw Exception(
        'The default branch »$resolvedBranch« carries the gg commit '
        '»$subject« ($hash). gg commits belong on feature branches only — '
        'main receives release merges and tags, nothing else.',
      );
    }
  }
}

// .............................................................................
/// The name of the default branch of [repo] — `main`, or `master` as
/// fallback.
Future<String> _defaultBranch(Directory repo) async {
  for (final candidate in ['main', 'master']) {
    final result = await Process.run('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      'refs/heads/$candidate',
    ], workingDirectory: repo.path);
    if (result.exitCode == 0) {
      return candidate;
    }
  }
  throw Exception(
    'Neither »main« nor »master« exists in ${repo.path} — '
    'pass the branch explicitly.',
  );
}
