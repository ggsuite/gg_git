// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// coverage:ignore-file

// #############################################################################
import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/src/commands/head.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// The command line interface for GgGit
class GgGit extends Command<dynamic> {
  /// Constructor
  GgGit({required this.ggLog}) {
    addSubcommand(GetTags(ggLog: ggLog));
    addSubcommand(IsCommitted(ggLog: ggLog));
    addSubcommand(IsPushed(ggLog: ggLog));
    addSubcommand(IsEolLf(ggLog: ggLog));
    addSubcommand(ModifiedFiles(ggLog: ggLog));
    addSubcommand(UnstagedFiles(ggLog: ggLog));
    addSubcommand(LastChangesHash(ggLog: ggLog));
    addSubcommand(Head(ggLog: ggLog));
    addSubcommand(CommitCount(ggLog: ggLog));
    addSubcommand(HasRemote(ggLog: ggLog));
    addSubcommand(UpstreamBranch(ggLog: ggLog));
    addSubcommand(LocalBranch(ggLog: ggLog));
    addSubcommand(IsFeatureBranch(ggLog: ggLog));
  }

  /// The log function
  final GgLog ggLog;

  // ...........................................................................
  @override
  final name = 'ggGit';
  @override
  final description = 'A collection of often used git commands.';
}
