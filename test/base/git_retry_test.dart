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
    });
  });
}
