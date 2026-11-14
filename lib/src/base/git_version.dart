// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/src/base/process_runner.dart';

/// Tells which git is installed, so a caller can use what a newer git offers
/// and fall back to the older way otherwise.
///
/// git is asked once per process — the answer does not change while it
/// runs — and never throws: a git that cannot be asked, or answers
/// something unreadable, counts as older than every version.
class GitVersion {
  /// Constructor. [processRunner] runs `git --version`.
  const GitVersion({this._processRunner = defaultProcessRunner})
    : _fixed = null;

  /// A git of the given version that is never asked, for tests.
  const GitVersion.fixed(int major, int minor)
    : _processRunner = defaultProcessRunner,
      _fixed = (major, minor);

  /// A git that cannot tell its version, for tests.
  const GitVersion.unknown()
    : _processRunner = defaultProcessRunner,
      _fixed = (0, 0);

  // ...........................................................................
  /// The first git that updates `origin/HEAD` while it fetches
  /// (`remote.<name>.followRemoteHEAD`).
  static const (int, int) followRemoteHead = (2, 48);

  // ...........................................................................
  /// Whether the installed git is version [major].[minor] or newer.
  Future<bool> isAtLeast(int major, int minor) async {
    final (installedMajor, installedMinor) = _fixed ?? await _installed();
    return installedMajor > major ||
        (installedMajor == major && installedMinor >= minor);
  }

  // ...........................................................................
  /// Forgets the version read so far, so the next question asks git again.
  static void reset() => _read = null;

  // ######################
  // Private
  // ######################

  final ProcessRunner _processRunner;
  final (int, int)? _fixed;

  /// The answer of the one `git --version` of this process.
  static Future<(int, int)>? _read;

  // ...........................................................................
  Future<(int, int)> _installed() => _read ??= _ask();

  // ...........................................................................
  Future<(int, int)> _ask() async {
    try {
      final result = await _processRunner('git', ['--version']);
      return parse('${result.stdout}');
    } on ProcessException {
      return (0, 0);
    }
  }

  // ...........................................................................
  /// Reads major and minor out of what `git --version` prints, e.g.
  /// `git version 2.56.0.windows.4`. `(0, 0)` when there is no version.
  static (int, int) parse(String output) {
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(output);
    return match == null
        ? (0, 0)
        : (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }
}
