// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

/// Waits for two things running at the same time and returns both results.
///
/// When one fails, the other one is still waited for before the error is
/// thrown — unlike `Future.wait(…, eagerError: true)`, which reports the
/// error while the other one keeps running. That matters for git calls: a
/// process that is still running holds on to its working directory, and
/// whoever was told about the failure must be free to remove it.
///
/// When both fail, the error of [first] is thrown, with its stack trace:
/// what the caller is told does not depend on which one was faster.
Future<(A, B)> waitForBoth<A, B>(Future<A> first, Future<B> second) async {
  try {
    return await (first, second).wait;
  } on ParallelWaitError<(A?, B?), (AsyncError?, AsyncError?)> catch (e) {
    final error = e.errors.$1 ?? e.errors.$2!;
    Error.throwWithStackTrace(error.error, error.stackTrace);
  }
}
