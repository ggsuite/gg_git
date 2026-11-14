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
/// error: a dropped connection, GitHub's SSH throttling, a 5xx reply, a
/// failed host name lookup or a connection that timed out.
///
/// A remote that answers with a **rate limit** — HTTP 429, GitHub's
/// »secondary rate limit« — is asked again as well, but after a much longer
/// wait ([rateLimitDelay], doubled with every retry): such a limit is
/// lifted after a minute or more, and asking earlier only prolongs it.
class GitRetry {
  /// Constructor
  const GitRetry({
    this.attempts = 4,
    this.baseDelay = const Duration(seconds: 5),
    this.rateLimitDelay = const Duration(seconds: 60),
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
      final stderr = '${result.stderr}';
      if (result.exitCode == 0 || !isTransient(stderr)) {
        break;
      }
      final rateLimited = isRateLimited(stderr);
      final delay = rateLimited
          ? delayAfterRateLimit(attempt - 1)
          : delayBeforeRetry(attempt - 1);
      final reason = rateLimited
          ? 'was turned away: the remote limits how often it is asked'
          : 'failed with a transient network error';
      ggLog(
        cDetail(
          '$description $reason. '
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
  /// The wait before the [retry]-th retry after a rate limit:
  /// [rateLimitDelay], doubled each time.
  Duration delayAfterRateLimit(int retry) =>
      rateLimitDelay * (1 << (retry - 1));

  // ...........................................................................
  /// Whether [stderr] shows a dropped or throttled connection, or a rate
  /// limit, rather than a real error such as rejected credentials or a
  /// missing repository.
  static bool isTransient(String stderr) {
    final text = stderr.toLowerCase();
    if (_permanent.any(text.contains)) {
      return false;
    }
    return _transient.any(text.contains) || _rateLimited.any(text.contains);
  }

  // ...........................................................................
  /// Whether [stderr] says the remote refused the request because the
  /// client asked too often: it has to wait before it asks again.
  static bool isRateLimited(String stderr) {
    final text = stderr.toLowerCase();
    return _rateLimited.any(text.contains);
  }

  /// How often the command runs at most, the first run included.
  final int attempts;

  /// The wait before the first retry.
  final Duration baseDelay;

  /// The wait before the first retry after a rate limit. GitHub asks a
  /// client it has limited to wait at least a minute.
  final Duration rateLimitDelay;

  /// Retries without waiting, for tests.
  static const GitRetry example = GitRetry(
    attempts: 3,
    baseDelay: Duration.zero,
    rateLimitDelay: Duration.zero,
  );

  // ######################
  // Private
  // ######################

  // ...........................................................................
  /// Messages that mean the transport dropped or throttled the connection,
  /// or never got one: a DNS lookup that failed for a moment, a timeout.
  /// A misspelled host or a blocked port shows the same messages; those
  /// fail again after the last attempt, only later.
  static const List<String> _transient = [
    // ssh: »Could not resolve hostname«, curl: »Could not resolve host«;
    // az (Python): »Name or service not known«.
    'could not resolve host',
    'temporary failure in name resolution',
    'name or service not known',
    // A connection that could not be opened or timed out.
    'failed to connect to',
    'error connecting to',
    'failed to establish a new connection',
    'connection timed out',
    'operation timed out',
    'network is unreachable',
    "couldn't connect to server",
    // A connection that dropped or was throttled.
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
  /// Messages of a remote that limits how often one client may ask.
  static const List<String> _rateLimited = [
    // GitHub: »API rate limit exceeded«, »You have exceeded a secondary
    // rate limit«; npm and pub.dev: »rate limit exceeded«.
    'rate limit',
    // Older wording of GitHub's secondary rate limit.
    'abuse detection',
    // The plain HTTP answer, as git, gh, curl and npm print it.
    'too many requests',
    'http 429',
    'returned error: 429',
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
