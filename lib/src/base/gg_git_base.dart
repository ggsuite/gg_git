// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/commands/is_locked.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:path/path.dart';

// #############################################################################
/// Base class for all ggGit commands
abstract class GgGitBase<T> extends DirCommand<T> {
  /// Constructor
  GgGitBase({
    required super.ggLog,
    required super.name,
    required super.description,
    GgProcessWrapper? processWrapper,
    IsLocked? isLocked,
  }) : processWrapper = processWrapper ?? const GgProcessWrapper(),
       _isLocked = isLocked;

  // ...........................................................................
  /// Returns true if everything in the directory is committed.
  @override
  Future<void> check({required Directory directory}) async {
    await super.check(directory: directory);

    // Does directory exist?
    final dirName = basename(canonicalize(directory.path));

    // Is directory a git repository?
    final gitDir = Directory('${directory.path}/.git');
    if (!(await gitDir.exists())) {
      throw ArgumentError('Directory "$dirName" is not a git repository.');
    }
  }

  // ...........................................................................
  /// Use this wrapper to run processes
  final GgProcessWrapper processWrapper;

  // ...........................................................................
  /// Reports if the repository is locked by another git process.
  late final IsLocked isLocked = _isLocked ?? IsLocked(ggLog: ggLog);

  // ...........................................................................
  /// Waits until no other git process writes the git index anymore.
  ///
  /// Call this before running a git command that writes `.git/index`, e.g.
  /// `git add`, `git commit` or `git checkout`. Those commands abort with
  /// `fatal: Unable to create '.../.git/index.lock': File exists.` when
  /// another git process is writing the index at the same time.
  Future<void> waitUntilUnlocked({
    required Directory directory,
    GgLog? ggLog,
  }) => isLocked.waitUntilUnlocked(
    directory: directory,
    ggLog: ggLog ?? this.ggLog,
  );

  // ######################
  // Private
  // ######################

  final IsLocked? _isLocked;
}

// #############################################################################
/// Example git command implementation
class GgGitCommandExample extends GgGitBase<String> {
  /// Constructor
  GgGitCommandExample({
    super.processWrapper,
    super.isLocked,
    required super.ggLog,
  }) : super(name: 'example', description: 'This is an example command.');

  // ...........................................................................
  @override
  Future<String> get({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    await check(directory: directory);
    return 'Example executed for "${dirName(directory)}".';
  }
}
