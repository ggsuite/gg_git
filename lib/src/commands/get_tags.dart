// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/src/base/gg_git_base.dart';

// #############################################################################
/// Provides "ggGit current-version-tag <dir>" command
class GetTags extends GgGitBase<void> {
  /// Constructor
  GetTags({
    required super.log,
    super.processWrapper,
  }) : super(
          name: 'get-tags',
          description: 'Retrieves the tags of the latest revision.',
        ) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<void> run({Directory? directory}) async {
    final inputDir = dir(directory);

    final headOnly = argResults!['head-only'] as bool;

    if (headOnly) {
      final result = await fromHead(directory: inputDir);

      log(result.isNotEmpty ? result.join('\n') : 'No head tags found.');
    } else {
      final result = await all(directory: inputDir);

      log(result.isNotEmpty ? result.join('\n') : 'No tags found.');
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<List<String>> fromHead({
    void Function(String)? log,
    required Directory directory,
  }) =>
      _getTags(
        args: ['--contains', 'HEAD'],
        log: log,
        directory: directory,
      );

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<List<String>> all({
    void Function(String)? log,
    required Directory directory,
  }) =>
      _getTags(
        args: [],
        log: log,
        directory: directory,
      );

  // ...........................................................................
  Future<List<String>> _getTags({
    required List<String> args,
    void Function(String)? log,
    required Directory directory,
  }) async {
    log ??= this.log;

    await check(directory: directory);

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
