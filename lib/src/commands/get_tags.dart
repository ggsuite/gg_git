// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Provides "ggGit current-version-tag dir" command
class GetTags extends GgGitBase<List<String>> {
  /// Constructor
  GetTags({
    required super.ggLog,
    super.processWrapper,
  }) : super(
          name: 'get-tags',
          description: 'Retrieves the tags of the latest revision.',
        ) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<List<String>> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final headOnly = argResults!['head-only'] as bool;
    late List<String> result;

    if (headOnly) {
      result = await fromHead(directory: directory, ggLog: ggLog);

      ggLog(result.isNotEmpty ? result.join('\n') : 'No head tags found.');
    } else {
      result = await all(directory: directory, ggLog: ggLog);

      ggLog(result.isNotEmpty ? result.join('\n') : 'No tags found.');
    }

    return result;
  }

  // ...........................................................................
  @override
  Future<List<String>> get({
    required GgLog ggLog,
    required Directory directory,
    bool headOnly = false,
  }) =>
      headOnly
          ? fromHead(ggLog: ggLog, directory: directory)
          : all(ggLog: ggLog, directory: directory);

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<List<String>> fromHead({
    required GgLog ggLog,
    required Directory directory,
  }) =>
      _getTags(
        args: ['--contains', 'HEAD'],
        ggLog: ggLog,
        directory: directory,
      );

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<List<String>> all({
    required GgLog ggLog,
    required Directory directory,
  }) =>
      _getTags(
        args: [],
        ggLog: ggLog,
        directory: directory,
      );

  // ...........................................................................
  Future<List<String>> _getTags({
    required List<String> args,
    required GgLog ggLog,
    required Directory directory,
  }) async {
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

/// Mocktail mock
class MockGetTags extends MockDirCommand<List<String>> implements GetTags {}
