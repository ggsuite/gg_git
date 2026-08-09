// @license
// Copyright (c) 2019 - 2026 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

/// Signature for running an external process (for injection & tests).
///
/// The one process-runner type of the gg_multi tool family. It carries
/// the superset of the parameters the family's modules need, so a single
/// injected runner serves them all. Implementations must accept every
/// named parameter; callers pass only what they care about.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool runInShell,
    });

/// Default [ProcessRunner] delegating to [Process.run].
///
/// Runs in a shell by default: the CLIs gg shells out to (`git`, `gh`,
/// `az`, the package managers) are wrapper scripts on some platforms and
/// resolve reliably through the shell.
Future<ProcessResult> defaultProcessRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell = true,
}) => Process.run(
  executable,
  arguments,
  workingDirectory: workingDirectory,
  environment: environment,
  runInShell: runInShell,
);
