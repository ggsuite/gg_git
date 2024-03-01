// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// #############################################################################
import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/add_version_tag.dart';
import 'package:gg_git/src/commands/version_from_changelog.dart';
import 'package:gg_git/src/commands/get_version.dart';
import 'package:gg_git/src/commands/get_tags.dart';
import 'package:gg_git/src/commands/version_from_git.dart';
import 'package:gg_git/src/commands/is_commited.dart';
import 'package:gg_git/src/commands/is_pushed.dart';
import 'package:gg_git/src/commands/version_from_pubspec.dart';

/// Gg Git
class GgGit {
  /// Constructor
  GgGit({
    required this.param,
    required this.log,
  });

  /// The param to work with
  final String param;

  /// The log function
  final void Function(String msg) log;

  /// The function to be executed
  Future<void> exec() async {
    log('Executing ggGit with param $param');
  }
}

// #############################################################################
/// The command line interface for GgGit
class GgGitCmd extends Command<dynamic> {
  /// Constructor
  GgGitCmd({required this.log}) {
    addSubcommand(AddVersionTag(log: log));
    addSubcommand(GetVersion(log: log));
    addSubcommand(GetTags(log: log));
    addSubcommand(VersionFromGit(log: log));
    addSubcommand(IsCommited(log: log));
    addSubcommand(IsPushed(log: log));
    addSubcommand(VersionFromPubspec(log: log));
    addSubcommand(VersionFromChangelog(log: log));
  }

  /// The log function
  final void Function(String message) log;

  // ...........................................................................
  @override
  final name = 'ggGit';
  @override
  final description = 'Add your description here.';
}
