// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_process/gg_process.dart';

// #############################################################################
/// Provides "ggGit current-version-tag <dir>" command
class GetTags extends GgGitBase {
  /// Constructor
  GetTags({
    required super.log,
    super.processWrapper,
  }) {
    _addArgs();
  }

  // ...........................................................................
  @override
  final name = 'get-tags';
  @override
  final description = 'Retrieves the tags of the latest revision.';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    final headOnly = argResults!['head-only'] as bool;

    if (headOnly) {
      final result = await fromHead(
        directory: inputDir,
        processWrapper: processWrapper,
        log: super.log,
      );

      log(result.isNotEmpty ? result.join('\n') : 'No head tags found.');
    } else {
      final result = await all(
        directory: inputDir,
        processWrapper: processWrapper,
        log: super.log,
      );

      log(result.isNotEmpty ? result.join('\n') : 'No tags found.');
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<List<String>> fromHead({
    required Directory directory,
    required GgProcessWrapper processWrapper,
    required void Function(String message) log,
  }) =>
      _getTags(
        directory: directory,
        processWrapper: processWrapper,
        args: ['--contains', 'HEAD'],
      );

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<List<String>> all({
    required Directory directory,
    required GgProcessWrapper processWrapper,
    required void Function(String message) log,
  }) =>
      _getTags(
        directory: directory,
        processWrapper: processWrapper,
        args: [],
      );

  // ...........................................................................
  static Future<List<String>> _getTags({
    required Directory directory,
    required GgProcessWrapper processWrapper,
    required List<String> args,
  }) async {
    await GgGitBase.checkDir(directory: directory);

    final result = await processWrapper.run(
      'git',
      ['tag', '-l', ...args],
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      final tags = (result.stdout as String)
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
        ..sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));

      return tags;
    }

    return [];
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addFlag(
      'head-only',
      abbr: 'l',
      help: 'Get only tags of the head revision',
      defaultsTo: false,
    );
  }
}
