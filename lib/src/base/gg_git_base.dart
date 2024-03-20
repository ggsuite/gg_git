// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_process/gg_process.dart';
import 'package:path/path.dart';

// #############################################################################
/// Base class for all ggGit commands
abstract class GgGitBase extends GgDirCommand {
  /// Constructor
  GgGitBase({
    required super.log,
    super.inputDir,
    GgProcessWrapper? processWrapper,
  }) : processWrapper = processWrapper ?? const GgProcessWrapper();

  // ...........................................................................
  /// Returns true if everything in the directory is committed.
  Future<void> checkDir({required Directory directory}) async {
    await GgDirCommand.checkDir(directory: directory);

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
}

// #############################################################################
/// Example git command implementation
class GgGitCommandExample extends GgGitBase {
  /// Constructor
  GgGitCommandExample({
    super.processWrapper,
    super.inputDir,
    required super.log,
  });

  // ...........................................................................
  @override
  final name = 'example';
  @override
  final description = 'This is an example command.';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();
    await checkDir(directory: inputDir);
    log('Example executed for "$inputDirName".');
  }
}
