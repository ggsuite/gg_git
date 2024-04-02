// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

// #############################################################################
/// Checks if the local git repo has a remote
class HasRemote extends GgGitBase<void> {
  /// Constructor
  HasRemote({
    required super.ggLog,
    super.processWrapper,
  }) : super(
          name: 'has-remote',
          description: 'Checks if local git repo has a remote.',
        );

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Has a remote.',
      ggLog: ggLog,
    );

    final result = await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );

    if (!result) {
      if (messages.isEmpty) {
        messages.add('Repo has no remote.');
      }

      throw Exception(brightBlack(messages.join('\n')));
    }
  }

  // ...........................................................................
  /// Returns true if the local git repo has a remote
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    await check(directory: directory);

    // Is everything committed?
    final result = await processWrapper.run(
      'git',
      ['remote'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not run "git remote" in "${dirName(directory)}": '
          '${result.stderr}');
    }

    return (result.stdout as String).isNotEmpty;
  }
}

/// Mocktail mock
class MockHasRemote extends mocktail.Mock implements HasRemote {}
