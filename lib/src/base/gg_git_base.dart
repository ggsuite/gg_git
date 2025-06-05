// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
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
  }) : processWrapper = processWrapper ?? const GgProcessWrapper();

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
}

// #############################################################################
/// Example git command implementation
class GgGitCommandExample extends GgGitBase<String> {
  /// Constructor
  GgGitCommandExample({super.processWrapper, required super.ggLog})
    : super(name: 'example', description: 'This is an example command.');

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
