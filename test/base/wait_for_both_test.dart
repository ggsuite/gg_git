// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';

import 'package:gg_git/gg_git.dart';
import 'package:test/test.dart';

void main() {
  group('waitForBoth', () {
    test('returns both results', () async {
      final (number, text) = await waitForBoth(
        Future.value(1),
        Future.value('one'),
      );

      expect(number, 1);
      expect(text, 'one');
    });

    test('runs both at the same time', () async {
      final first = Completer<int>();
      final second = Completer<String>();
      final both = waitForBoth(first.future, second.future);

      // The second one finishes while the first one still runs.
      second.complete('two');
      first.complete(2);

      expect(await both, (2, 'two'));
    });

    test('waits for the second one before it reports the failure of the '
        'first', () async {
      final second = Completer<String>();
      var isDone = false;
      final both = waitForBoth(
        Future<int>.error(StateError('first')),
        second.future,
      ).whenComplete(() => isDone = true);
      both.ignore();

      await Future<void>.delayed(Duration.zero);
      expect(isDone, isFalse);

      second.complete('two');
      await expectLater(both, throwsStateError);
    });

    test('waits for the first one before it reports the failure of the '
        'second', () async {
      final first = Completer<int>();
      var isDone = false;
      final both = waitForBoth(
        first.future,
        Future<String>.error(ArgumentError('second')),
      ).whenComplete(() => isDone = true);
      both.ignore();

      await Future<void>.delayed(Duration.zero);
      expect(isDone, isFalse);

      first.complete(1);
      await expectLater(both, throwsArgumentError);
    });

    test('throws the error of the first one when both fail, with its stack '
        'trace', () async {
      final first = Completer<int>();
      final both = waitForBoth(
        first.future,
        Future<String>.error(ArgumentError('second')),
      );
      both.ignore();

      // The second one failed long ago.
      await Future<void>.delayed(Duration.zero);
      first.completeError(
        StateError('first'),
        StackTrace.fromString('stack of the first'),
      );

      Object? error;
      StackTrace? stackTrace;
      try {
        await both;
      } catch (e, s) {
        error = e;
        stackTrace = s;
      }

      expect(error, isStateError);
      expect('$stackTrace', contains('stack of the first'));
    });
  });
}
