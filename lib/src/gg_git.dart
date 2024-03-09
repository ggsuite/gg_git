// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// coverage:ignore-file

// #############################################################################
import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/get_tags.dart';
import 'package:gg_git/src/commands/is_committed.dart';
import 'package:gg_git/src/commands/is_pushed.dart';

// #############################################################################
/// The command line interface for GgGit
class GgGit extends Command<dynamic> {
  /// Constructor
  GgGit({required this.log}) {
    addSubcommand(GetTags(log: log));
    addSubcommand(IsCommitted(log: log));
    addSubcommand(IsPushed(log: log));
  }

  /// The log function
  final void Function(String message) log;

  // ...........................................................................
  @override
  final name = 'ggGit';
  @override
  final description = 'A collection of often used git commands.';
}
