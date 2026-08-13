// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_log/gg_log.dart';
import 'package:path/path.dart';

// #############################################################################
/// Checks if a git repository is locked by another git process.
///
/// While git writes the index, it creates a `.git/index.lock` file. A second
/// git process writing the index at the same time aborts with
/// `fatal: Unable to create '.../.git/index.lock': File exists.`.
///
/// Use [get] to ask for the current lock state and [waitUntilUnlocked] to
/// wait until the other git process has finished.
class IsLocked extends GgGitBase<bool> {
  /// Constructor
  IsLocked({
    required super.ggLog,
    super.processWrapper,
    this.timeout = defaultTimeout,
    this.interval = defaultInterval,
  }) : super(
         name: 'is-locked',
         description:
             'Checks if the git repository is locked by another git process.',
       );

  // ...........................................................................
  /// The default time [waitUntilUnlocked] waits for the lock to disappear.
  static const Duration defaultTimeout = Duration(minutes: 2);

  /// The default time between two checks of the lock file.
  static const Duration defaultInterval = Duration(milliseconds: 250);

  /// The time [waitUntilUnlocked] waits for the lock to disappear.
  final Duration timeout;

  /// The time between two checks of the lock file.
  final Duration interval;

  // ...........................................................................
  /// The lock file git creates while it writes the index.
  File lockFile(Directory directory) =>
      File(join(canonicalize(directory.path), '.git', 'index.lock'));

  // ...........................................................................
  /// Returns true when another git process is currently writing the index.
  @override
  Future<bool> get({required Directory directory, required GgLog ggLog}) =>
      lockFile(directory).exists();

  // ...........................................................................
  /// Waits until no other git process writes the git index anymore.
  ///
  /// Returns immediately when the repository is not locked. Otherwise it
  /// informs the user and polls the lock file every [interval] until it
  /// disappears. Throws when the lock is still there after [timeout].
  @override
  Future<void> waitUntilUnlocked({
    required Directory directory,
    GgLog? ggLog,
  }) async {
    final log = ggLog ?? this.ggLog;

    if (!await get(directory: directory, ggLog: log)) {
      return;
    }

    final path = lockFile(directory).path;

    log(yellow('Waiting until ') + blue(path) + yellow(' disappears.'));

    final stopwatch = Stopwatch()..start();

    while (await get(directory: directory, ggLog: log)) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception(
          '"$path" did not disappear within ${timeout.inSeconds} seconds. '
          'Another git process seems to be running in this repository. '
          'Please make sure all processes are terminated. If a git process '
          'has crashed earlier, remove the file manually to continue.',
        );
      }

      await Future<void>.delayed(interval);
    }
  }
}

/// Mocktail mock
class MockIsLocked extends MockDirCommand<bool> implements IsLocked {}
