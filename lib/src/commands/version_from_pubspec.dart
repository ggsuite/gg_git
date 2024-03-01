// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:checked_yaml/checked_yaml.dart';
import 'package:gg_git/src/base/gg_dir_base.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

// #############################################################################
/// Provides "ggGit current-version-tag <dir>" command
class VersionFromPubspec extends GgDirBase {
  /// Constructor
  VersionFromPubspec({
    required super.log,
  });

  // ...........................................................................
  @override
  final name = 'version-from-pubspec';
  @override
  final description = 'Returns the version found in pubspec.yaml';

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
    final pubspec = File('$directory/pubspec.yaml');
    final dirName = basename(canonicalize(directory));

    if (!pubspec.existsSync()) {
      throw Exception('File "$dirName/pubspec.yaml" does not exist.');
    }

    return fromString(content: pubspec.readAsStringSync());
  }

  // ...........................................................................
  /// Parses version from pubspec.yaml
  static Version fromString({
    required String content,
  }) {
    late Pubspec pubspec;

    try {
      pubspec = Pubspec.parse(content);
    } on ParsedYamlException catch (e) {
      throw Exception(e.message);
    }

    if (pubspec.version == null) {
      throw Exception('Could not find version in "pubspec.yaml".');
    }

    return pubspec.version!;
  }
}
