// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:path/path.dart' as p;

import 'ssh_host_keys.dart';

/// Watches git network commands — clone, fetch, push, ls-remote — while they
/// run, where `Process.run` shows nothing until the command ends.
///
/// A remote can turn a request away and still keep the connection open:
/// Azure DevOps prints »VS403463: The conditional access policy … has
/// failed« and leaves git waiting for hours. The watch reads stderr while
/// git runs, ends git as soon as such a message arrives
/// ([isFatalRemoteMessage]) and returns the failure with the message, so
/// the caller can say what to do.
///
/// A command that stays silent for [quietNotice] is reported to `ggLog`,
/// again after every further [quietNotice], so gg never waits without a
/// word. The command keeps running: a large clone is silent for a while.
///
/// [GitRetry] watches every attempt it runs, see [watch].
class GitWatch {
  /// Constructor
  const GitWatch({this.quietNotice = const Duration(seconds: 30)});

  /// How long a command may stay silent before gg says that it still waits.
  final Duration quietNotice;

  // ...........................................................................
  /// Runs [body] with the git commands it runs through `ggRunProcess` or
  /// `GgProcessWrapper.run` watched, whatever process runner the caller
  /// uses, as long as it ends in [GgProcessDelegate.current].
  ///
  /// Everything else is passed through unchanged: other programs (`gh`),
  /// processes started with `ggStartProcess`, output asked for as bytes,
  /// and every command while a delegate other than the default one is
  /// installed — an embedder or a test that answers commands itself. An
  /// injected fake runner never gets there at all.
  ///
  /// [description] names the command in the notices to [ggLog].
  Future<T> watch<T>(
    Future<T> Function() body, {
    required GgLog ggLog,
    required String description,
  }) {
    final current = GgProcessDelegate.current;
    if (!identical(current, GgProcessDelegate.defaultDelegate)) {
      return body();
    }
    return GgProcessDelegate.runWith(
      _WatchingDelegate(this, ggLog: ggLog, description: description),
      body,
    );
  }

  // ...........................................................................
  /// Runs [executable] with [arguments] and returns its result once it has
  /// ended — or once its stderr showed a [isFatalRemoteMessage] and it was
  /// ended. [description] names the command in the notices to [ggLog].
  ///
  /// The process is started by the default delegate, never in a shell:
  /// ending it must end git, not a shell around it. Unlike a process of
  /// `ggStartProcess` it is not killed with the [GgProcessScope] it runs
  /// in: like every process of `ggRunProcess` it is left to finish. Output
  /// is decoded as `Process.run` decodes it.
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    required GgLog ggLog,
    required String description,
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    Encoding stdoutEncoding = systemEncoding,
    Encoding stderrEncoding = systemEncoding,
  }) async {
    final process = await _delegate.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
    );
    // Nobody answers a prompt of git: it ends with an error instead of
    // waiting for input.
    unawaited(process.stdin.close());

    final stdout = StringBuffer();
    final stderr = StringBuffer();
    final fatal = Completer<void>();
    final started = DateTime.now();
    final quiet = _QuietNotice(quietNotice, () {
      final seconds = DateTime.now().difference(started).inSeconds;
      ggLog(
        cDetail(
          '$description has been running for ${seconds}s without an '
          'answer, still waiting. If it never ends, stop gg with Ctrl+C '
          'and run the command alone to see what the remote says.',
        ),
      );
    });

    Future<void> read(
      Stream<List<int>> stream,
      Encoding encoding,
      void Function(String) onText,
    ) => stream.transform(encoding.decoder).forEach((chunk) {
      onText(chunk);
      quiet.heard();
    });

    // Only the new stderr is searched, together with the end of the text
    // before it, where a message may have been cut.
    var tail = '';
    void watchStderr(String chunk) {
      stderr.write(chunk);
      final text = tail + chunk;
      if (!fatal.isCompleted && isFatalRemoteMessage(text)) {
        fatal.complete();
      }
      tail = text.substring(math.max(0, text.length - _overlap));
    }

    final output = Future.wait([
      read(process.stdout, stdoutEncoding, stdout.write),
      read(process.stderr, stderrEncoding, watchStderr),
    ]);

    try {
      await Future.any([
        Future.wait([process.exitCode, output]),
        fatal.future,
      ]);
      // git may also have ended by itself right after the message.
      final exitCode = fatal.isCompleted
          ? await process.exitCode
                .then<int?>((c) => c)
                .timeout(_exitGrace, onTimeout: () => null)
          : await process.exitCode;
      if (exitCode != null) {
        return ProcessResult(process.pid, exitCode, '$stdout', '$stderr');
      }

      // The remote turned the request away and git still waits. Its ssh may
      // keep the output pipes open after git has ended, so they are not
      // waited for.
      await _end(process);
      return ProcessResult(process.pid, 128, '$stdout', '$stderr');
    } finally {
      quiet.stop();
    }
  }

  // ...........................................................................
  /// Whether [stderr] holds a message with which the remote turns a request
  /// away for good, while it may still keep the connection open: a failed
  /// conditional access policy of Azure DevOps, see
  /// [SshHostKeys.isConditionalAccessFailure].
  static bool isFatalRemoteMessage(String stderr) =>
      SshHostKeys.isConditionalAccessFailure(stderr);

  /// Whether [executable] names git, the one program [watch] watches.
  /// The Windows context splits at `/` and `\` alike, so a Windows path
  /// is recognized on every host.
  static bool isGit(String executable) =>
      p.windows.basenameWithoutExtension(executable).toLowerCase() == 'git';

  /// Watches without notices, for tests.
  static const GitWatch example = GitWatch(quietNotice: Duration(hours: 1));

  // ######################
  // Private
  // ######################

  /// Starts and ends the watched processes: [watch] installs itself only
  /// over this one.
  static const _delegate = GgProcessDelegate.defaultDelegate;

  /// How much of the stderr read before a chunk is searched with it: more
  /// than the length of any message [isFatalRemoteMessage] looks for.
  static const int _overlap = 32;

  /// How long git may take to end by itself after a fatal message before
  /// it is ended.
  static const _exitGrace = Duration(milliseconds: 500);

  // ...........................................................................
  /// Ends [process] together with the ssh it started: killing git alone
  /// leaves ssh holding the connection. Where the tool for that cannot run
  /// (`pkill` missing in a minimal container), git alone is ended; its ssh
  /// then ends once the remote closes the connection.
  Future<void> _end(Process process) async {
    final pid = '${process.pid}';
    // coverage:ignore-start
    try {
      if (ggPlatform.isWindows) {
        await _delegate.run('taskkill', ['/PID', pid, '/T', '/F']);
      } else {
        await _delegate.run('pkill', ['-TERM', '-P', pid]);
      }
    } on Exception {
      // Ended below.
    }
    // coverage:ignore-end
    process.kill();
    await process.exitCode;
  }
}

// #############################################################################
/// Tells [notice] after every [interval] without output, with one timer per
/// silence rather than one per chunk of output.
class _QuietNotice {
  _QuietNotice(this.interval, this.notice) {
    _schedule(interval);
  }

  final Duration interval;
  final void Function() notice;

  var _lastHeard = DateTime.now();
  Timer? _timer;
  var _stopped = false;

  /// Output arrived: the silence starts anew.
  void heard() => _lastHeard = DateTime.now();

  /// No more notices, also not for output that still arrives.
  void stop() {
    _stopped = true;
    _timer?.cancel();
  }

  void _schedule(Duration delay) => _timer = Timer(delay, () {
    if (_stopped) {
      return; // coverage:ignore-line
    }
    final silent = DateTime.now().difference(_lastHeard);
    if (silent >= interval) {
      notice();
      _lastHeard = DateTime.now();
      _schedule(interval);
    } else {
      _schedule(interval - silent);
    }
  });
}

// #############################################################################
/// Runs the git commands through [GitWatch.run] and passes everything else
/// to the default delegate, see [GitWatch.watch].
class _WatchingDelegate extends GgProcessDelegate {
  _WatchingDelegate(
    this._watch, {
    required this._ggLog,
    required this._description,
  });

  final GitWatch _watch;
  final GgLog _ggLog;
  final String _description;

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
  }) {
    if (!GitWatch.isGit(executable) ||
        stdoutEncoding == null ||
        stderrEncoding == null) {
      return GitWatch._delegate.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        stdoutEncoding: stdoutEncoding,
        stderrEncoding: stderrEncoding,
      );
    }
    return _watch.run(
      executable,
      arguments,
      ggLog: _ggLog,
      description: workingDirectory == null
          ? _description
          : '$_description in $workingDirectory',
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) => GitWatch._delegate.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
    mode: mode,
  );
}
