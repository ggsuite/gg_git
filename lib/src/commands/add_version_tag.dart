// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/src/base/gg_git_base.dart';
import 'package:gg_git/src/commands/get_version.dart';
import 'package:gg_git/src/commands/is_commited.dart';
import 'package:gg_process/gg_process.dart';

// #############################################################################
/// Provides "ggGit has-version-tag <dir>" command
class AddVersionTag extends GgGitBase {
  /// Constructor
  AddVersionTag({
    required super.log,
    super.processWrapper,
  });

  // ...........................................................................
  @override
  final name = 'add-version-tag';
  @override
  final description = 'Reads version from pubspec.yaml and adds it as git tag';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    String? lastLog;

    await add(
      directory: directory,
      processWrapper: processWrapper,
      log: (msg) {
        lastLog = msg;
        log(msg);
      },
    );

    log(lastLog ?? 'Version tag added.');
  }

  // ...........................................................................
  /// Returns true if everything in the directory is pushed.
  static Future<bool> add({
    required String directory,
    required GgProcessWrapper processWrapper,
    required void Function(String message) log,
  }) async {
    // Throw if not everything is commited
    final isCommited = await IsCommited.isCommited(
      directory: directory,
      processWrapper: processWrapper,
    );

    if (!isCommited) {
      throw StateError('Not everything is commited.');
    }

    final versions = await GetVersion.versions(
      directory: directory,
      processWrapper: processWrapper,
      log: log,
    );

    // If version is already set, do nothing
    final pubspecVersion = versions.pubspec;
    final changeLogVersion = versions.changeLog;
    final tagVersion = versions.gitHead;
    final latestVersion = versions.gitLatest;

    if (pubspecVersion == changeLogVersion && pubspecVersion == tagVersion) {
      log('Version already set.');
      return true;
    }

    // If version in pubspec is not equal to version in change log, throw
    if (pubspecVersion != changeLogVersion) {
      throw Exception(
        'Version in pubspec.yaml is not equal version in CHANGELOG.md.',
      );
    }

    // If head already has a version tag, throw
    if (tagVersion != null) {
      throw Exception('Head has already a version tag.');
    }

    // If version in pubspec is smaller latest version, throw
    if (latestVersion != null && pubspecVersion <= latestVersion) {
      throw Exception(
        'Version in pubspec.yaml and CHANGELOG.md must be greater '
        '${latestVersion.toString()}',
      );
    }

    // Create a tag and push it
    final version = pubspecVersion.toString();
    final result = await processWrapper.run(
      'git',
      ['tag', '-a', version, '-m', 'Version $version'],
      workingDirectory: directory,
    );

    if (result.exitCode == 0) {
      log('Tag $version added.');
      return true;
    } else {
      throw Exception('Could not add tag $version: ${result.stderr}');
    }
  }
}
