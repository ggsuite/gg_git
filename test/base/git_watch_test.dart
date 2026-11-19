// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];
  late Directory tmp;

  const conditionalAccess =
      'remote: VS403463: The conditional access policy defined by your '
      'Microsoft Entra administrator has failed.';
  const azureUrl = 'git@ssh.dev.azure.com:v3/org/project/repo';

  /// The git arguments of an ls-remote of [azureUrl] that reaches, instead
  /// of Azure, an ssh that runs [script].
  List<String> lsRemoteWithSsh(String script) => [
    '-c',
    'ssh.variant=ssh',
    '-c',
    'core.sshCommand=${writeFakeSsh(tmp, script)}',
    'ls-remote',
    azureUrl,
  ];

  setUp(() async {
    messages.clear();
    tmp = await initTestDir();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group('GitWatch', () {
    group('run', () {
      test('returns the output of a command that ends', () async {
        final result = await GitWatch.example.run(
          'git',
          ['--version'],
          ggLog: messages.add,
          description: 'git --version',
        );

        expect(result.exitCode, 0);
        expect(result.stdout, startsWith('git version'));
        expect(messages, isEmpty);
      });

      test('returns the failure of a command that fails', () async {
        final result = await GitWatch.example.run(
          'git',
          lsRemoteWithSsh('echo "Connection refused" >&2; exit 255'),
          ggLog: messages.add,
          description: 'git ls-remote',
        );

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('Connection refused'));
      });

      test(
        'ends git when the remote turns it away but stays connected',
        () async {
          // Azure prints VS403463 and keeps the connection open: git would
          // wait for hours.
          final stopwatch = Stopwatch()..start();
          final result = await GitWatch.example.run(
            'git',
            lsRemoteWithSsh('echo "$conditionalAccess" >&2\nread line'),
            ggLog: messages.add,
            description: 'git ls-remote',
            workingDirectory: tmp.path,
          );

          expect(result.exitCode, 128);
          expect(result.stderr, contains('VS403463'));
          expect(stopwatch.elapsed, lessThan(const Duration(seconds: 60)));
        },
        timeout: const Timeout(Duration(seconds: 90)),
      );

      test('reports a command that stays silent', () async {
        const watch = GitWatch(quietNotice: Duration(milliseconds: 100));

        final result = await GitWatch.example.watch(
          () => watch.run(
            'git',
            lsRemoteWithSsh('sleep 1; echo "Connection closed" >&2; exit 255'),
            ggLog: messages.add,
            description: 'git ls-remote',
          ),
          ggLog: messages.add,
          description: 'outer',
        );

        expect(result.exitCode, isNot(0));
        expect(messages, isNotEmpty);
        expect(messages.first, contains('git ls-remote has been running'));
        expect(messages.first, contains('without an answer, still waiting'));
        expect(messages.first, contains('Ctrl+C'));
      });
    });

    group('watch', () {
      test('watches what the body runs through ggRunProcess', () async {
        const watch = GitWatch(quietNotice: Duration(milliseconds: 100));

        final result = await watch.watch(
          () => ggRunProcess(
            'git',
            lsRemoteWithSsh('echo "$conditionalAccess" >&2\nread line'),
          ),
          ggLog: messages.add,
          description: 'git ls-remote',
        );

        expect(result.exitCode, 128);
        expect(result.stderr, contains('VS403463'));
      });

      test('names the folder in its notices', () async {
        const watch = GitWatch(quietNotice: Duration(milliseconds: 100));

        await watch.watch(
          () => const GgProcessWrapper().run(
            'git',
            lsRemoteWithSsh('sleep 1; exit 255'),
            workingDirectory: tmp.path,
          ),
          ggLog: messages.add,
          description: 'git ls-remote',
        );

        expect(messages.first, contains('git ls-remote in ${tmp.path} has'));
      });

      test('passes started processes through', () async {
        final process = await GitWatch.example.watch(
          () => ggStartProcess('git', ['--version']),
          ggLog: messages.add,
          description: 'git --version',
        );

        expect(await process.exitCode, 0);
      });

      test('reaches no process outside its body', () async {
        final inside = GitWatch.example.watch(
          () async => GgProcessDelegate.current,
          ggLog: messages.add,
          description: 'git',
        );

        expect(await inside, isNot(GgProcessDelegate.defaultDelegate));
        expect(GgProcessDelegate.current, GgProcessDelegate.defaultDelegate);
      });

      test('returns the exit code of a git that ended by itself', () async {
        // The message arrives, and git ends on its own right after.
        final result = await GitWatch.example.watch(
          () => ggRunProcess(
            'git',
            lsRemoteWithSsh('echo "$conditionalAccess" >&2; exit 255'),
          ),
          ggLog: messages.add,
          description: 'git ls-remote',
        );

        expect(result.exitCode, 128);
        expect(result.stderr, contains('Could not read from remote'));
      });

      test('passes other programs and output as bytes through', () async {
        final results = await GitWatch.example.watch(
          () async => [
            await ggRunProcess(Platform.resolvedExecutable, ['--version']),
            await ggRunProcess(
              'git',
              ['--version'],
              stdoutEncoding: null,
              stderrEncoding: null,
            ),
          ],
          ggLog: messages.add,
          description: 'git',
        );

        expect(results[0].exitCode, 0);
        expect(results[1].stdout, isA<List<int>>());
      });

      test('leaves a delegate other than the default one alone', () async {
        final embedder = _Embedder();
        GgProcessDelegate.current = embedder;
        addTearDown(() => GgProcessDelegate.current = null);

        final result = await GitWatch.example.watch(
          () => ggRunProcess('git', ['push']),
          ggLog: messages.add,
          description: 'git push',
        );

        expect(result.stdout, 'answered');
        expect(embedder.calls, ['git push']);
      });
    });

    test('isGit', () {
      expect(GitWatch.isGit('git'), isTrue);
      expect(GitWatch.isGit(r'C:\Program Files\Git\cmd\git.exe'), isTrue);
      expect(GitWatch.isGit('/usr/bin/git'), isTrue);
      expect(GitWatch.isGit('gh'), isFalse);
      expect(GitWatch.isGit('gitk'), isFalse);
    });

    test('isFatalRemoteMessage', () {
      expect(GitWatch.isFatalRemoteMessage(conditionalAccess), isTrue);
      expect(GitWatch.isFatalRemoteMessage('remote: vs403463: …'), isTrue);
      expect(
        GitWatch.isFatalRemoteMessage(
          'remote: Public key authentication failed.',
        ),
        isFalse,
      );
      expect(GitWatch.isFatalRemoteMessage(''), isFalse);
      // A ref name holds no colon: a branch a fetch lists never matches.
      expect(
        GitWatch.isFatalRemoteMessage(
          ' * [new branch]  fix_vs403463_hint -> origin/fix_vs403463_hint',
        ),
        isFalse,
      );
    });
  });
}

/// A delegate that answers every command itself, like an embedder.
class _Embedder extends GgProcessDelegate {
  final calls = <String>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    calls.add([executable, ...arguments].join(' '));
    return ProcessResult(0, 0, 'answered', '');
  }
}
