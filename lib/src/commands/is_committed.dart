// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

// #############################################################################
/// Provides "ggGit committed <dir>" command
class IsCommitted extends GgGitBase<void> {
  /// Constructor
  IsCommitted({
    required super.log,
    super.processWrapper,
  }) : super(
          name: 'is-committed',
          description:
              'Is everything in the current working directory committed?',
        );

  // ...........................................................................
  @override
  Future<void> run({Directory? directory}) async {
    final inputDir = dir(directory);

    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is committed.',
      log: log,
    );

    final result = await printer.logTask(
      task: () => get(log: messages.add, directory: inputDir),
      success: (success) => success,
    );

    if (!result) {
      if (messages.isEmpty) {
        messages.add('There are uncommmited changes.');
      }

      throw Exception("$brightBlack${messages.join('\n')}$reset");
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is committed.
  Future<bool> get({
    void Function(String msg)? log,
    required Directory directory,
  }) async {
    log ??= this.log;
    await check(directory: directory);

    // Is everything committed?
    final result = await processWrapper.run(
      'git',
      ['status', '--porcelain'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not run "git status" in "${dirName(directory)}".');
    }

    return (result.stdout as String).isEmpty;
  }
}

/// Mocktail mock
class MockIsCommited extends mocktail.Mock implements IsCommitted {}
