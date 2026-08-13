// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_process/gg_process.dart';

/// Signature for running an external process (for injection & tests).
///
/// The one process-runner type of the gg_multi tool family. It carries
/// the superset of the parameters the family's modules need, so a single
/// injected runner serves them all. Implementations must accept every
/// named parameter; callers pass only what they care about.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell,
});

/// Default [ProcessRunner] delegating to [GgProcessDelegate.current].
///
/// Never calls `Process.run` directly, so an embedder — gg running as
/// WebAssembly, say — can redirect it. See [GgProcessDelegate].
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
}) => ggRunProcess(
  executable,
  arguments,
  workingDirectory: workingDirectory,
  environment: environment,
  runInShell: runInShell,
);
