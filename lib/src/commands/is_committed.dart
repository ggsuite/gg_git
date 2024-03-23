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
/// Checks if eyerything in the current working directory is committed.
class IsCommitted extends GgGitBase<void> {
  /// Constructor
  IsCommitted({
    required super.ggLog,
    super.processWrapper,
  }) : super(
          name: 'is-committed',
          description:
              'Is everything in the current working directory committed?',
        );

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is committed.',
      ggLog: ggLog,
    );

    final result = await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );

    if (!result) {
      if (messages.isEmpty) {
        messages.add('There are uncommmited changes.');
      }

      throw Exception(brightBlack(messages.join('\n')));
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is committed.
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
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
class MockIsCommitted extends mocktail.Mock implements IsCommitted {}
