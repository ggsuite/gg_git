// @license
// Copyright (c) 2019 - 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/gg_git.dart';
import 'package:test/test.dart';

void main() {
  group('ggCommitPrefix', () {
    test('ends with a space so »#ggfoo« is not mistaken for a gg commit', () {
      expect(ggCommitPrefix, '#gg: ');
      expect(isGgGenerated('#ggfoo'), isFalse);
    });
  });

  group('ggMergeBackPrefix', () {
    test('is itself a gg commit message', () {
      expect(ggMergeBackPrefix.startsWith(ggCommitPrefix), isTrue);
      expect(
        isGgGenerated('${ggMergeBackPrefix}main back into CDM-1685'),
        isTrue,
      );
    });
  });

  group('isGgGenerated(subject)', () {
    test('returns true for a subject carrying the prefix', () {
      expect(isGgGenerated('#gg: changed references to pub.dev'), isTrue);
      expect(isGgGenerated('#gg: some future bookkeeping step'), isTrue);
    });

    test('returns true for every legacy subject', () {
      for (final subject in legacyGgCommitMessages) {
        expect(isGgGenerated(subject), isTrue, reason: subject);
      }
    });

    test('ignores surrounding whitespace', () {
      expect(isGgGenerated('  #gg: Update pubspec.lock  '), isTrue);
      expect(isGgGenerated('  gg_multi: changed references to path  '), isTrue);
    });

    test('returns false for a manual subject', () {
      expect(isGgGenerated('Fix login bug'), isFalse);
      expect(isGgGenerated(''), isFalse);
      expect(isGgGenerated('Merge branch main into CDM-1685'), isFalse);
    });

    test('returns false for a legacy subject that only starts alike', () {
      expect(
        isGgGenerated('gg_multi: changed references to path and more'),
        isFalse,
      );
    });
  });
}
