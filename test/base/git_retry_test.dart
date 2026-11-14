// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];
  const dropped =
      'Connection to github.com closed by remote host.\n'
      'fatal: Could not read from remote repository.';

  /// A command that answers with [exitCodes], one per call, and counts calls.
  (Future<ProcessResult> Function(), List<int>) command(List<int> exitCodes) {
    final calls = <int>[];
    Future<ProcessResult> run() async {
      final exitCode = exitCodes[calls.length];
      calls.add(exitCode);
      return ProcessResult(0, exitCode, '', exitCode == 0 ? '' : dropped);
    }

    return (run, calls);
  }

  setUp(messages.clear);

  group('GitRetry', () {
    group('run', () {
      test('returns the first result when the command succeeds', () async {
        final (run, calls) = command([0]);

        final result = await GitRetry.example.run(
          run,
          ggLog: messages.add,
          description: 'git push',
        );

        expect(result.exitCode, 0);
        expect(calls, [0]);
        expect(messages, isEmpty);
      });

      test('does not retry a permanent failure', () async {
        var calls = 0;
        Future<ProcessResult> run() async {
          calls++;
          return ProcessResult(0, 128, '', 'ERROR: Repository not found.');
        }

        final result = await GitRetry.example.run(
          run,
          ggLog: messages.add,
          description: 'git push',
        );

        expect(result.exitCode, 128);
        expect(calls, 1);
        expect(messages, isEmpty);
      });

      test('retries a transient failure until the command succeeds', () async {
        final (run, calls) = command([1, 0]);

        final result = await GitRetry.example.run(
          run,
          ggLog: messages.add,
          description: 'git push',
        );

        expect(result.exitCode, 0);
        expect(calls, [1, 0]);
        expect(
          rmControls(messages.single),
          [
            'git push failed with a transient network error. ',
            'Retrying in 0s (attempt 2 of 3).',
          ].join(),
        );
      });

      test('gives up after the last attempt', () async {
        final (run, calls) = command([1, 1, 1, 1]);

        final result = await GitRetry.example.run(
          run,
          ggLog: messages.add,
          description: 'git fetch',
        );

        expect(result.exitCode, 1);
        expect(result.stderr, dropped);
        expect(calls, [1, 1, 1]);
        expect(messages.map(rmControls), [
          contains('Retrying in 0s (attempt 2 of 3).'),
          contains('Retrying in 0s (attempt 3 of 3).'),
        ]);
      });
    });

    group('run after a rate limit', () {
      const limited =
          'HTTP 403: You have exceeded a secondary rate limit. Please wait a '
          'few minutes before you try again.';

      /// A command the remote turns away [times] times before it succeeds.
      (Future<ProcessResult> Function(), List<int>) limitedCommand(int times) {
        final calls = <int>[];
        Future<ProcessResult> run() async {
          final exitCode = calls.length < times ? 1 : 0;
          calls.add(exitCode);
          return ProcessResult(0, exitCode, '', exitCode == 0 ? '' : limited);
        }

        return (run, calls);
      }

      test(
        'tries again and says that the remote limits the requests',
        () async {
          final (run, calls) = limitedCommand(1);

          final result = await GitRetry.example.run(
            run,
            ggLog: messages.add,
            description: 'gh pr create',
          );

          expect(result.exitCode, 0);
          expect(calls, [1, 0]);
          expect(
            rmControls(messages.single),
            [
              'gh pr create was turned away: the remote limits how often it ',
              'is asked. Retrying in 0s (attempt 2 of 3).',
            ].join(),
          );
        },
      );

      test('waits the rate limit delay, not the short one', () async {
        const retry = GitRetry(
          attempts: 2,
          baseDelay: Duration.zero,
          rateLimitDelay: Duration(seconds: 1),
        );
        final (run, _) = limitedCommand(1);
        final stopwatch = Stopwatch()..start();

        await retry.run(run, ggLog: messages.add, description: 'git push');

        expect(rmControls(messages.single), contains('Retrying in 1s'));
        expect(
          stopwatch.elapsed,
          greaterThan(const Duration(milliseconds: 900)),
        );
      });

      test('gives up after the last attempt', () async {
        final (run, calls) = limitedCommand(10);

        final result = await GitRetry.example.run(
          run,
          ggLog: messages.add,
          description: 'gh pr create',
        );

        expect(result.exitCode, 1);
        expect(result.stderr, limited);
        expect(calls, [1, 1, 1]);
      });
    });

    group('delayAfterRateLimit', () {
      test('starts with a minute and doubles with every retry', () {
        const retry = GitRetry();
        expect(retry.rateLimitDelay, const Duration(seconds: 60));
        expect(retry.delayAfterRateLimit(1), const Duration(minutes: 1));
        expect(retry.delayAfterRateLimit(2), const Duration(minutes: 2));
        expect(retry.delayAfterRateLimit(3), const Duration(minutes: 4));
      });
    });

    group('isRateLimited', () {
      test('is true when the remote says the client asks too often', () {
        for (final stderr in [
          // gh, GitHub REST
          'HTTP 403: API rate limit exceeded for user ID 1.',
          'You have exceeded a secondary rate limit and have been '
              'temporarily blocked from content creation.',
          'You have triggered an abuse detection mechanism.',
          // git over https
          'error: RPC failed; HTTP 429 curl 22 The requested URL returned '
              'error: 429',
          'fatal: unable to access \'https://github.com/a/b.git/\': The '
              'requested URL returned error: 429',
          // npm, pub
          'npm error code E429\nnpm error 429 Too Many Requests - PUT '
              'https://registry.npmjs.org/a',
          'Rate limit exceeded, please try again later.',
        ]) {
          expect(GitRetry.isRateLimited(stderr), isTrue, reason: stderr);
          expect(GitRetry.isTransient(stderr), isTrue, reason: stderr);
        }
      });

      test('is false for other failures', () {
        for (final stderr in [
          '',
          'Connection to github.com closed by remote host.',
          'fatal: repository not found',
          'error: failed to push some refs',
        ]) {
          expect(GitRetry.isRateLimited(stderr), isFalse, reason: stderr);
        }
      });

      test('does not make a real error worth a retry', () {
        const stderr =
            'remote: Permission denied to a/b.\n'
            'remote: API rate limit exceeded';
        expect(GitRetry.isTransient(stderr), isFalse);
      });
    });

    group('delayBeforeRetry', () {
      test('triples the base delay with every retry', () {
        const retry = GitRetry();
        expect(retry.attempts, 4);
        expect(retry.delayBeforeRetry(1), const Duration(seconds: 5));
        expect(retry.delayBeforeRetry(2), const Duration(seconds: 15));
        expect(retry.delayBeforeRetry(3), const Duration(seconds: 45));
      });
    });

    group('isTransient', () {
      test('is true for a dropped or throttled connection', () {
        for (final stderr in [
          dropped,
          'kex_exchange_identification: Connection closed by remote host',
          'ssh_dispatch_run_fatal: Connection to 140.82.121.4 port 22: '
              'Broken pipe',
          'client_loop: send disconnect: Connection reset by peer',
          'error: RPC failed; curl 56 OpenSSL SSL_read: Connection reset\n'
              'fatal: the remote end hung up unexpectedly',
          'fatal: early EOF\nfatal: fetch-pack: invalid index-pack output',
          'error: RPC failed; HTTP 503 curl 22 The requested URL returned '
              'error: 503',
          'fatal: unexpected disconnect while reading sideband packet',
        ]) {
          expect(GitRetry.isTransient(stderr), isTrue, reason: stderr);
        }
      });

      test('is true for gh and az when the host does not answer', () {
        for (final stderr in [
          'error connecting to api.github.com\n'
              'check your internet connection or https://githubstatus.com',
          // az (Python requests) when dev.azure.com does not resolve.
          'HTTPSConnectionPool(host=\'dev.azure.com\', port=443): Max retries '
              'exceeded (Caused by NewConnectionError(\'<urllib3.connection '
              'object>: Failed to establish a new connection: '
              '[Errno -2] Name or service not known\'))',
        ]) {
          expect(GitRetry.isTransient(stderr), isTrue, reason: stderr);
        }
      });
      test('is true for a failed host name lookup or a timeout', () {
        for (final stderr in [
          'ssh: Could not resolve hostname github.com: '
              'Der angegebene Host ist unbekannt.\r\n'
              'fatal: Could not read from remote repository.',
          'ssh: Could not resolve hostname github.com: '
              'Temporary failure in name resolution\n'
              'fatal: Could not read from remote repository.',
          "fatal: unable to access 'https://github.com/x/y.git/': "
              'Could not resolve host: github.com',
          'ssh: connect to host github.com port 22: Connection timed out\n'
              'fatal: Could not read from remote repository.',
          "fatal: unable to access 'https://github.com/x/y.git/': "
              'Failed to connect to github.com port 443 after 21 ms: '
              "Couldn't connect to server",
          "fatal: unable to access 'https://github.com/x/y.git/': "
              'Operation timed out after 300000 milliseconds',
          'ssh: connect to host github.com port 22: Network is unreachable',
        ]) {
          expect(GitRetry.isTransient(stderr), isTrue, reason: stderr);
        }
      });

      test('is false for a real error', () {
        for (final stderr in [
          'git@github.com: Permission denied (publickey).\n'
              'fatal: Could not read from remote repository.',
          'ERROR: Repository not found.\n'
              'fatal: Could not read from remote repository.',
          ' ! [rejected]        main -> main (non-fast-forward)',
          'remote: Invalid username or password.\n'
              'fatal: Authentication failed for \'https://github.com/x/y/\'',
          'fatal: could not read Username for \'https://github.com\'',
          'Some error',
          '',
        ]) {
          expect(GitRetry.isTransient(stderr), isFalse, reason: stderr);
        }
      });

      test('is false when a real error comes with a dropped connection', () {
        const stderr =
            'remote: error: GH006: Protected branch update failed\n'
            ' ! [remote rejected] main -> main (protected branch hook '
            'declined)\nfatal: the remote end hung up unexpectedly';
        expect(GitRetry.isTransient(stderr), isFalse);
      });
    });

    test('example retries without waiting', () {
      expect(GitRetry.example.attempts, 3);
      expect(GitRetry.example.baseDelay, Duration.zero);
      expect(GitRetry.example.rateLimitDelay, Duration.zero);
    });
  });
}
