// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_process/gg_process.dart';
import 'package:path/path.dart';

// #############################################################################
/// Provides "ggGit is-pushed <dir>" command
class IsPushed extends GgGitBase {
  /// Constructor
  IsPushed({
    required super.log,
    super.processWrapper,
  });

  // ...........................................................................
  @override
  final name = 'is-pushed';
  @override
  final description = 'Is everything in the current working directory pushed?';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();
    String? lastLog;

    final result = await isPushed(
      directory: inputDir,
      processWrapper: processWrapper,
      log: (msg) {
        log(msg);
        lastLog = msg;
      },
    );

    if (result) {
      log('Everything is pushed.');
    } else {
      throw Exception(lastLog ?? 'There are unpushed changes.');
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<bool> isPushed({
    required String directory,
    required GgProcessWrapper processWrapper,
    required void Function(String message) log,
  }) async {
    // Is everything pushed?
    final result = await processWrapper.run(
      'git',
      ['status'],
      workingDirectory: directory,
    );

    final directoryName = basename(canonicalize(directory));

    if (result.exitCode != 0) {
      throw Exception('Could not run "git push" in "$directoryName".');
    }

    final stdout = result.stdout as String;

    if (stdout.contains('Your branch is ahead')) {
      log('The local branch is ahead of remote branch.');
      return false;
    } else if (stdout.contains('Your branch is behind')) {
      log('Local branch is behind remote branch.');
      return false;
    } else if (stdout.contains('Untracked files')) {
      log('There are untracked files.');
      return false;
    } else if (stdout.contains('Changes to be committed')) {
      log('There are staged but uncommited changes.');
      return false;
    } else if (stdout.contains('Changes not staged for commit')) {
      log('There are not-added files.');
      return false;
    } else if (stdout.contains('Your branch is up to date')) {
      log('Everything is pushed.');
      return true;
    } else if (stdout.contains('nothing to commit, working tree clean')) {
      log('The branch has no remote.');
      return false;
    }

    throw Exception('Unknown status of "git push" in "$directoryName".');
  }
}
