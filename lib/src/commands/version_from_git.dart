// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_git/src/commands/get_tags.dart';
import 'package:gg_process/gg_process.dart';
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Provides "ggGit current-version-tag <dir>" command
class VersionFromGit extends GgGitBase {
  /// Constructor
  VersionFromGit({
    required super.log,
    super.processWrapper,
  }) {
    _addArgs();
  }

  // ...........................................................................
  @override
  final name = 'version-from-git';
  @override
  final description =
      'Returns the version tag of the latest state or nothing if not tagged';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    final headOnly = argResults!['head-only'] as bool;

    if (headOnly) {
      final result = await fromHead(
        directory: directory,
        processWrapper: processWrapper,
        log: super.log,
      );

      log(result?.toString() ?? 'No version tag found in head.');
    } else {
      final result = await latest(
        directory: directory,
        processWrapper: processWrapper,
        log: super.log,
      );

      log(result?.toString() ?? 'No version tag found.');
    }
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<Version?> fromHead({
    required String directory,
    required GgProcessWrapper processWrapper,
    required void Function(String message) log,
  }) async {
    await GgGitBase.checkDir(directory: directory);

    final headTags = await GetTags.fromHead(
      directory: directory,
      processWrapper: processWrapper,
      log: log,
    );

    final versions = _getVersions(headTags);
    if (versions.length > 1) {
      throw StateError(
        'There are multiple version tags for the latest revision.\n'
        'Please remove all but one.',
      );
    }

    return versions.firstOrNull;
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<Version?> latest({
    required String directory,
    required GgProcessWrapper processWrapper,
    required void Function(String message) log,
  }) async {
    await GgGitBase.checkDir(directory: directory);

    final tags = await GetTags.all(
      directory: directory,
      processWrapper: processWrapper,
      log: log,
    );

    final versions = _getVersions(tags);
    return versions.firstOrNull;
  }

  // ...........................................................................
  static List<Version> _getVersions(List<String> tags) {
    final versions = <Version>[];
    for (final tag in tags) {
      try {
        final version = Version.parse(tag);
        versions.add(version);
      } catch (e) {
        // ignore
      }
    }
    return versions;
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addFlag(
      'head-only',
      abbr: 'l',
      help: 'Get only version assigned to head revision',
      defaultsTo: false,
    );
  }
}
