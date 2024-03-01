// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/version_from_changelog.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  late Directory d;
  final messages = <String>[];

  setUp(() {
    d = initTestDir();
    messages.clear();
  });

  group('ChangeLogVersion', () {
    group('fromDirectory(directory)', () {
      group('should throw', () {
        test('if no CHANGELOG.md file is found in directory', () async {
          await expectLater(
            () => VersionFromChangelog.fromDirectory(directory: d.path),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: File "test/CHANGELOG.md" does not exist.',
              ),
            ),
          );
        });
      });

      group('should return version', () {
        test('when found in CHANGELOG.md', () async {
          await setChangeLog(d, version: '0.0.1');
          final version =
              await VersionFromChangelog.fromDirectory(directory: d.path);
          expect(version, Version.parse('0.00.001'));
        });
      });
    });

    group('fromString(content)', () {
      group('should throw', () {
        // .....................................................................
        test('if CHANGELOG.md has no version tag', () {
          const content = 'name: test';

          expect(
            () => VersionFromChangelog.fromString(content: content),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: Could not find version in "CHANGELOG.md".',
              ),
            ),
          );
        });

        // .....................................................................
        test('if CHANGELOG.md contains invalid version', () {
          const content = '# Change Log\n\n## 0.x.7\n\n- test';

          expect(
            () => VersionFromChangelog.fromString(content: content),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Exception: Version "0.x.7" has invalid format.',
                ),
              ),
            ),
          );
        });
      });

      group('should succeed', () {
        test('and return the version foun in CHANGELOG.md', () {
          const content = '# Change Log\n\n## 1.2.3\n\n- test';
          final version = VersionFromChangelog.fromString(content: content);
          expect(version, Version.parse('01.02.003'));
        });
      });
    });

    group('run()', () {
      group('should return the version', () {
        test('when found in CHANGELOG.md', () async {
          await setChangeLog(d, version: '1.0.0');
          final runner = CommandRunner<void>('test', 'test')
            ..addCommand(VersionFromChangelog(log: messages.add));

          await runner.run(['version-from-changelog', d.path]);
          expect(messages.last, '1.0.0');
        });
      });
    });
  });
}
