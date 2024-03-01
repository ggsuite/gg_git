// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_process/gg_process.dart';
import 'package:path/path.dart';

// #############################################################################
/// Provides "ggGit is-commited <dir>" command
class IsCommited extends GgGitBase {
  /// Constructor
  IsCommited({
    required super.log,
    super.processWrapper,
  });

  // ...........................................................................
  @override
  final name = 'is-commited';
  @override
  final description =
      'Is everything in the current working directory commited?';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    final result = await isCommited(
      directory: directory,
      processWrapper: processWrapper,
    );

    if (result) {
      log('Everything is commited.');
    } else {
      throw Exception('There are uncommited changes.');
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is commited.
  static Future<bool> isCommited({
    required String directory,
    required GgProcessWrapper processWrapper,
  }) async {
    await GgGitBase.checkDir(directory: directory);
    final directoryName = basename(canonicalize(directory));

    // Is everything commited?
    final result = await processWrapper.run(
      'git',
      ['status', '--porcelain'],
      workingDirectory: directory,
    );
    if (result.exitCode != 0) {
      throw Exception('Could not run "git status" in "$directoryName".');
    }

    return (result.stdout as String).isEmpty;
  }
}
