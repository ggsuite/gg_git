// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:path/path.dart';

/// Returns if automatic line feed conversion is on or not
class IsEolLf extends GgGitBase<bool> {
  /// Constructor
  IsEolLf({
    required super.ggLog,
    super.processWrapper,
    UpstreamBranch? upstreamBranch,
  }) : super(
         name: 'is-eol-lf',
         description: 'Is automatic conversion of line feeds enabled?',
       );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Is line feed enabled?',
      ggLog: ggLog,
    );

    final result = await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );

    return result;
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    final gitAttributesPath = join(directory.path, '.gitattributes');

    final file = File(gitAttributesPath);

    if (!(await file.exists())) {
      return false;
    }

    final content = (await file.readAsLines())
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'));

    bool hasEolLf = false;
    bool hasTextAuto = false;

    for (final line in content) {
      final lower = line.toLowerCase();
      if (lower.contains('eol=lf')) {
        hasEolLf = true;
      }
      if (lower.contains('text=auto')) {
        hasTextAuto = true;
      }
    }

    final result = hasEolLf || hasTextAuto;

    return result;
  }

  // ...........................................................................
  /// Throws when line endings are not set to linux and EOL conversion is OFF
  Future<void> throwWhenNotLf({required Directory directory}) async {
    // Throw if repository does not use linux line feeds internally
    final convertsLineFeeds = await get(directory: directory, ggLog: ggLog);

    if (!convertsLineFeeds) {
      throw Exception(
        [
          'Git automatic EOL conversion is OFF.',
          '  1. Create a file ".gitattributes" in the root of this repo',
          '  2. Open .gitattributes with a text editor.',
          '  3. Add the following line:',
          '      * text=auto eol=lf',
        ].join('\n'),
      );
    }
  }
}

/// Mocktail mock
class MockIsAutoConversionOn extends MockDirCommand<bool> implements IsEolLf {}
