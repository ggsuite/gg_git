// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'dart:math' as math;

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

/// Reruns a git network command that failed with a transient transport
/// error: a dropped connection, GitHub's SSH throttling, a 5xx reply.
class GitRetry {
  /// Constructor
  const GitRetry({
    this.attempts = 4,
    this.baseDelay = const Duration(seconds: 5),
  });

  // ...........................................................................
  /// Runs [command] until it succeeds, fails for a permanent reason or
  /// [attempts] is used up. Returns the last result; the caller reports it.
  Future<ProcessResult> run(
    Future<ProcessResult> Function() command, {
    required GgLog ggLog,
    required String description,
  }) async {
    var result = await command();
    for (var attempt = 2; attempt <= attempts; attempt++) {
      if (result.exitCode == 0 || !isTransient('${result.stderr}')) {
        break;
      }
      final delay = delayBeforeRetry(attempt - 1);
      ggLog(
        cDetail(
          '$description failed with a transient network error. '
          'Retrying in ${delay.inSeconds}s (attempt $attempt of $attempts).',
        ),
      );
      await Future<void>.delayed(delay);
      result = await command();
    }
    return result;
  }

  // ...........................................................................
  /// The wait before the [retry]-th retry: [baseDelay] tripled each time.
  Duration delayBeforeRetry(int retry) =>
      baseDelay * math.pow(3, retry - 1).toInt();

  // ...........................................................................
  /// Whether [stderr] shows a dropped or throttled connection rather than a
  /// real error such as rejected credentials or a missing repository.
  static bool isTransient(String stderr) {
    final text = stderr.toLowerCase();
    if (_permanent.any(text.contains)) {
      return false;
    }
    return _transient.any(text.contains);
  }

  /// How often the command runs at most, the first run included.
  final int attempts;

  /// The wait before the first retry.
  final Duration baseDelay;

  /// Retries without waiting, for tests.
  static const GitRetry example = GitRetry(
    attempts: 3,
    baseDelay: Duration.zero,
  );

  // ######################
  // Private
  // ######################

  // ...........................................................................
  /// Messages that mean the transport dropped or throttled the connection.
  static const List<String> _transient = [
    'closed by remote host',
    'connection reset by peer',
    'broken pipe',
    'kex_exchange_identification',
    'the remote end hung up unexpectedly',
    'early eof',
    'rpc failed',
    'unexpected disconnect',
    'returned error: 502',
    'returned error: 503',
    'returned error: 504',
  ];

  // ...........................................................................
  /// Messages that name a real problem a retry cannot fix.
  static const List<String> _permanent = [
    'permission denied',
    'repository not found',
    'authentication failed',
    'could not read username',
    'rejected',
  ];
}

/// Mock for [GitRetry].
class MockGitRetry extends Mock implements GitRetry {}
