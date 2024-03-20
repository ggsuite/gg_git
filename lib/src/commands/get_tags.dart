// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/src/base/gg_git_base.dart';

// #############################################################################
/// Provides "ggGit current-version-tag <dir>" command
class GetTags extends GgGitBase {
  /// Constructor
  GetTags({
    required super.log,
    super.processWrapper,
    super.inputDir,
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
      final result = await fromHead;

      log(result.isNotEmpty ? result.join('\n') : 'No head tags found.');
    } else {
      final result = await all;

      log(result.isNotEmpty ? result.join('\n') : 'No tags found.');
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<List<String>> get fromHead => _getTags(
        args: ['--contains', 'HEAD'],
      );

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  Future<List<String>> get all => _getTags(
        args: [],
      );

  // ...........................................................................
  Future<List<String>> _getTags({
    required List<String> args,
  }) async {
    await checkDir(directory: inputDir);

    final result = await processWrapper.run(
      'git',
      ['tag', '-l', ...args],
      workingDirectory: inputDir.path,
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
