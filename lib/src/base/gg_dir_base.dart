// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

// #############################################################################
/// Base class for all ggGit commands
abstract class GgDirBase extends Command<dynamic> {
  /// Constructor
  GgDirBase({
    required this.log,
  }) {
    _addArgs();
  }

  /// The log function
  final void Function(String message) log;

  // ...........................................................................
  @mustCallSuper
  @override
  Future<void> run() async {
    directory = argResults!['directory'] as String;
    directoryName = basename(canonicalize(directory));
  }

  // ...........................................................................
  /// Returns true if everything in the directory is commited.
  static Future<void> checkDir({required String directory}) async {
    // Does directory exist?
    final dirName = basename(canonicalize(directory));

    final dir = Directory(directory);
    if (!(await dir.exists())) {
      throw ArgumentError('Directory "$dirName" does not exist.');
    }
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addOption(
      'directory',
      abbr: 'd',
      help: 'The directory to be checked.',
      defaultsTo: '.',
    );
  }

  /// The directory to be checked
  late String directory;

  /// The name of the directory to be checked
  late String directoryName;
}

// #############################################################################
/// Example git command implementation
class GgDirCommandExample extends GgDirBase {
  /// Constructor
  GgDirCommandExample({
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
    await GgDirBase.checkDir(directory: directory);
    super.log('Example executed for "$directoryName".');
  }
}
