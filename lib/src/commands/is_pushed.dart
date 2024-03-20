// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

// #############################################################################
/// Provides "ggGit pushed <dir>" command
class IsPushed extends GgGitBase {
  /// Constructor
  IsPushed({
    required super.log,
    super.processWrapper,
    super.inputDir,
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

    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is pushed.',
      log: log,
    );

    final result = await printer.logTask(
      task: () => _get(log: messages.add),
      success: (success) => success,
    );

    if (!result) {
      throw Exception("$brightBlack${messages.join('\n')}$reset");
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<bool> get() => _get(log: log);

  // ...........................................................................
  Future<bool> _get({
    required void Function(String) log,
  }) async {
    // Is everything pushed?
    final result = await processWrapper.run(
      'git',
      ['status'],
      workingDirectory: inputDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception('Could not run "git push" in "$inputDirName".');
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
      log('There are staged but uncommitted changes.');
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

    throw Exception('Unknown status of "git push" in "$inputDirName".');
  }
}
