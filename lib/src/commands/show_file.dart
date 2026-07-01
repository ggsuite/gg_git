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
/// Returns the content of a file at a git ref via `git show <ref>:<path>`.
class ShowFile extends GgGitBase<String?> {
  /// Constructor
  ShowFile({required super.ggLog, super.processWrapper})
    : super(name: 'show-file', description: 'Shows a file at a git ref.');

  // ...........................................................................
  @override
  Future<String?> exec({
    required Directory directory,
    required GgLog ggLog,
    String? ref,
    String? filePath,
  }) => get(directory: directory, ggLog: ggLog, ref: ref, filePath: filePath);

  // ...........................................................................
  /// Returns the content of [filePath] at [ref], or null when it does not
  /// exist there. Throws on a missing [ref] or [filePath].
  @override
  Future<String?> get({
    required GgLog ggLog,
    required Directory directory,
    String? ref,
    String? filePath,
  }) async {
    ref ??= _argAt(0);
    filePath ??= _argAt(1);
    if (ref == null || ref.isEmpty || filePath == null || filePath.isEmpty) {
      throw ArgumentError('Missing ref or filePath.');
    }

    final result = await processWrapper.run('git', [
      'show',
      '$ref:$filePath',
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      return null;
    }

    return result.stdout.toString();
  }

  // ...........................................................................
  /// The i-th positional CLI argument, or null when absent.
  String? _argAt(int i) => argResults != null && argResults!.rest.length > i
      ? argResults!.rest[i]
      : null;
}

/// Mocktail mock
class MockShowFile extends MockDirCommand<String?> implements ShowFile {}
