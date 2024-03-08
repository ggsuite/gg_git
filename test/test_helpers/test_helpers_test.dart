// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_git/src/test_helpers/test_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('TestHelpers', () {
    test('should work fine', () async {
      // const TestHelpers();
      final testDir = initTestDir();
      expect(await testDir.exists(), isTrue);
      testDir.deleteSync(recursive: true);
    });
  });
}
