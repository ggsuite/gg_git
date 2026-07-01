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
/// Checks out an existing branch (creating a tracking branch from the remote
/// when the branch only exists on `origin`).
class Checkout extends GgGitBase<void> {
  /// Constructor
  Checkout({required super.ggLog, super.processWrapper})
    : super(name: 'checkout', description: 'Checks out an existing branch.');

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    String? branch,
  }) => get(directory: directory, ggLog: ggLog, branch: branch);

  // ...........................................................................
  /// Checks out [branch]. Throws on a missing name or a failed checkout.
  @override
  Future<void> get({
    required GgLog ggLog,
    required Directory directory,
    String? branch,
  }) async {
    branch ??= _argAt(0);
    if (branch == null || branch.isEmpty) {
      throw ArgumentError('Missing branch name.');
    }

    final result = await processWrapper.run('git', [
      'checkout',
      branch,
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      final out = (result.stdout as String).trim();
      final detail = err.isNotEmpty ? err : out;
      throw Exception(
        'Could not checkout "$branch" in "${dirName(directory)}": $detail.',
      );
    }
  }

  // ...........................................................................
  /// The i-th positional CLI argument, or null when absent.
  String? _argAt(int i) => argResults != null && argResults!.rest.length > i
      ? argResults!.rest[i]
      : null;
}

/// Mocktail mock
class MockCheckout extends MockDirCommand<void> implements Checkout {}
