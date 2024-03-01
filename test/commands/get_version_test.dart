// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/src/commands/get_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  final messages = <String>[];
  late Directory d;

  // ...........................................................................
  Future<Version> getVersion() => GetVersion.consistantVersion(
        directory: d.path,
        log: (m) => messages.add(m),
      );

  // ...........................................................................
  setUp(() {
    d = initTestDir();
    messages.clear();
  });

  // ...........................................................................
  setUp(() {
    messages.clear();
  });

  group('GetVersion', () {
    group('versions(...)', () {
      group('should throw', () {
        test('if not everything is commited', () async {
          await initGit(d);
          initUncommitedFile(d);
          await expectLater(
            () => GetVersion.versions(
              directory: d.path,
              log: (m) => messages.add(m),
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Please commit everything in "test".'),
              ),
            ),
          );
        });
      });

      group('should return the versions', () {
        group('found int pubspec, CHANGELOG and git tag', () {
          group('if everything is commited ', () {
            test('and head revision has version tag', () async {
              await initGit(d);

              // Set old revision
              await setupVersions(
                d,
                pubspec: '1.2.3',
                changeLog: '4.5.6',
                gitHead: '7.8.9',
              );

              // Set head revision
              await setupVersions(
                d,
                pubspec: '2.2.3',
                changeLog: '5.5.6',
                gitHead: '8.8.9',
              );

              final result = await GetVersion.versions(
                directory: d.path,
                log: (m) => messages.add(m),
              );

              // Latest version should be returned
              expect(result.pubspec, Version.parse('2.2.3'));
              expect(result.changeLog, Version.parse('5.5.6'));
              expect(result.gitHead, Version.parse('8.8.9'));
              expect(result.gitLatest, Version.parse('8.8.9'));
            });

            test('and no revision has a version tag', () async {
              await initGit(d);
              await setupVersions(
                d,
                pubspec: '1.2.3',
                changeLog: '1.2.3',
                gitHead: null,
              );

              final result = await GetVersion.versions(
                directory: d.path,
                log: (m) => messages.add(m),
              );

              expect(result.pubspec.toString(), '1.2.3');
              expect(result.changeLog.toString(), '1.2.3');
              expect(result.gitHead, null);
              expect(result.gitLatest, null);
            });

            test('only previous revisions have a version tag', () async {
              await initGit(d);
              // Set old revision
              await setupVersions(
                d,
                pubspec: '1.2.3',
                changeLog: '4.5.6',
                gitHead: '7.8.9',
              );

              // Add another commit
              await updateAndCommitSampleFile(d);

              // Get versions
              final result = await GetVersion.versions(
                directory: d.path,
                log: (m) => messages.add(m),
              );

              // Latest version should be returned
              expect(result.pubspec, Version.parse('1.2.3'));
              expect(result.changeLog, Version.parse('4.5.6'));
              expect(result.gitHead, null); // Head has no version
              expect(result.gitLatest, Version.parse('7.8.9'));
            });
          });
        });
      });
    });

    group('consistantVersion(...)', () {
      group('should throw', () {
        test('if CHANGELOG version does not match the others', () async {
          await initGit(d);
          await setupVersions(
            d,
            pubspec: '1.0.0',
            changeLog: '2.0.0',
            gitHead: '1.0.0',
          );

          await expectLater(
            () => getVersion(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Versions are not consistent:'),
              ),
            ),
          );
        });

        test('if no git version tag exists', () async {
          await initGit(d);
          await setupVersions(
            d,
            pubspec: '1.0.0',
            changeLog: '1.0.0',
            gitHead: null,
          );

          await expectLater(
            () => getVersion(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Current state has no git version tag.'),
              ),
            ),
          );
        });

        test('if Pubspec version does not match the others', () async {
          await initGit(d);
          await setupVersions(
            d,
            pubspec: '2.0.0',
            changeLog: '1.0.0',
            gitHead: '1.0.0',
          );

          await expectLater(
            () => getVersion(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Versions are not consistent:'),
              ),
            ),
          );
        });

        test('if Git head version does not match the others', () async {
          await initGit(d);
          await setupVersions(
            d,
            pubspec: '1.0.0',
            changeLog: '1.0.0',
            gitHead: '0.0.0',
          );

          await expectLater(
            () => getVersion(),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Versions are not consistent:'),
              ),
            ),
          );
        });
      });

      group('should return the consistent version', () {
        test('if all versions are consistent', () async {
          await initGit(d);
          await setupVersions(
            d,
            pubspec: '1.2.3',
            changeLog: '1.2.3',
            gitHead: '1.2.3',
          );
          final result = await getVersion();
          expect(result.toString(), '1.2.3');
        });
      });
    });

    group('run()', () {
      test('should return the consistent version', () async {
        final runner = CommandRunner<void>('test', 'test')
          ..addCommand(GetVersion(log: messages.add));

        await initGit(d);
        await setupVersions(
          d,
          pubspec: '1.2.3',
          changeLog: '1.2.3',
          gitHead: '1.2.3',
        );

        await runner.run(['get-version', '--directory', d.path]);
        expect(messages, ['1.2.3']);
      });
    });
  });
}
