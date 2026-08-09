// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:path/path.dart' as path;
import 'package:gg_git/src/base/process_runner.dart';

/// Runs git with [args] in [repoDir] using [runner] and returns the trimmed
/// stdout.
///
/// Throws when git exits non-zero, unless [allowFailure] is set (used for
/// commands like `git merge --abort`/`git rebase --abort` that legitimately
/// fail when there is nothing to abort).
///
/// Shared by `do review` and `do publish` so their rollback paths use one
/// git runner instead of drifting copies.
/// Set [trimmed] to false when the raw stdout matters — the columns of
/// `git status --porcelain` are positional and a leading space is meaningful
/// (» M file« is modified but unstaged), so trimming corrupts the first line.
Future<String> runGit(
  ProcessRunner runner,
  List<String> args, {
  required Directory repoDir,
  bool allowFailure = false,
  bool trimmed = true,
}) async {
  final result = await runner('git', args, workingDirectory: repoDir.path);
  if (!allowFailure && result.exitCode != 0) {
    final stderrStr = result.stderr?.toString().trim() ?? '';
    final stdoutStr = result.stdout?.toString().trim() ?? '';
    final detail = stderrStr.isNotEmpty ? stderrStr : stdoutStr;
    throw Exception(
      cError(
        'git ${args.join(' ')} failed in '
        '${path.basename(repoDir.path)}: $detail',
      ),
    );
  }
  final out = result.stdout?.toString() ?? '';
  return trimmed ? out.trim() : out;
}

/// Captures the uncommitted changes of [repoDir] — tracked modifications, the
/// staged/unstaged split *and* untracked files — in a dangling stash commit,
/// leaving the working tree exactly as it was. Returns the stash commit hash,
/// or null when [status] shows nothing to preserve.
///
/// `git stash create` cannot include untracked files, so this pushes a stash
/// (which momentarily clears the tree), records its hash and immediately
/// re-applies it. The hash keeps working after the `drop` (the commit is only
/// dangling) and is re-applied with `git stash apply --index` on restore,
/// which also reinstates the original staged/unstaged split.
Future<String?> captureUncommitted(
  ProcessRunner runner, {
  required Directory repoDir,
  required String status,
}) async {
  if (status.isEmpty) {
    return null;
  }
  await runGit(runner, <String>[
    'stash',
    'push',
    '--include-untracked',
    '--message',
    'gg-multi snapshot',
  ], repoDir: repoDir);
  final sha = await runGit(runner, <String>[
    'rev-parse',
    'stash@{0}',
  ], repoDir: repoDir);
  await runGit(runner, <String>[
    'stash',
    'apply',
    '--index',
    'stash@{0}',
  ], repoDir: repoDir);
  await runGit(runner, <String>[
    'stash',
    'drop',
    'stash@{0}',
  ], repoDir: repoDir);
  return sha;
}
