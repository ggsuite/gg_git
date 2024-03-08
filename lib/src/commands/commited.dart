// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_git/src/tools/is_github.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:path/path.dart';

// #############################################################################
/// Provides "ggGit commited <dir>" command
class Commited extends GgGitBase {
  /// Constructor
  Commited({
    required super.log,
    super.processWrapper,
  });

  // ...........................................................................
  @override
  final name = 'commited';
  @override
  final description =
      'Is everything in the current working directory commited?';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is commited.',
      printCallback: log,
      useCarriageReturn: !isGitHub,
    );

    final result = await printer.logTask(
      task: () => isCommited(
        directory: inputDir,
        processWrapper: processWrapper,
      ),
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
  /// Returns true if everything in the directory is commited.
  static Future<bool> isCommited({
    required Directory directory,
    required GgProcessWrapper processWrapper,
  }) async {
    await GgGitBase.checkDir(directory: directory);
    final directoryName = basename(canonicalize(directory.path));

    // Is everything commited?
    final result = await processWrapper.run(
      'git',
      ['status', '--porcelain'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not run "git status" in "$directoryName".');
    }

    return (result.stdout as String).isEmpty;
  }
}
