// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';

/// Commands for retrieving information about the head revision.
class Head extends Command<void> {
  /// Constructor
  Head({
    required this.ggLog,
    this.name = 'head',
    this.description =
        'Commands for retrieving information about the head revision.',
  }) {
    addSubcommand(HeadHash(ggLog: ggLog));
    addSubcommand(HeadMessage(ggLog: ggLog));
  }

  /// The log function
  final GgLog ggLog;

  // ...........................................................................
  @override
  final String name;
  @override
  final String description;
}
