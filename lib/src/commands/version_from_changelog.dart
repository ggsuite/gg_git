// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/src/base/gg_dir_base.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Provides "ggGit current-version-tag <dir>" command
class VersionFromChangelog extends GgDirBase {
  /// Constructor
  VersionFromChangelog({
    required super.log,
  });

  // ...........................................................................
  @override
  final name = 'version-from-changelog';
  @override
  final description = 'Returns the version found in CHANGELOG.md';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    final result = await fromDirectory(
      directory: directory,
    );

    log(result.toString());
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<Version> fromDirectory({required String directory}) async {
    await GgDirBase.checkDir(directory: directory);
    final pubspec = File('$directory/CHANGELOG.md');
    final dirName = basename(canonicalize(directory));

    if (!pubspec.existsSync()) {
      throw Exception('File "$dirName/CHANGELOG.md" does not exist.');
    }

    return fromString(content: pubspec.readAsStringSync());
  }

  // ...........................................................................
  /// Parses version from pubspec.yaml
  static Version fromString({
    required String content,
  }) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.startsWith('## ')) {
        final version = line.split(' ')[1].trim();
        try {
          return Version.parse(version);
        } catch (e) {
          throw Exception(
            'Version "$version" has invalid format.',
          );
        }
      }
    }

    throw Exception('Could not find version in "CHANGELOG.md".');
  }
}
