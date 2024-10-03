// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:gg_git/gg_git.dart';
import 'package:path/path.dart';
import 'package:recase/recase.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];

  setUp(() {
    messages.clear();
  });

  group('GgGit()', () {
    // #########################################################################
    group('GgGit', () {
      final ggGit = GgGit(ggLog: (msg) => messages.add(msg));

      final CommandRunner<void> runner = CommandRunner<void>(
        'ggGit',
        'Description goes here.',
      )..addCommand(ggGit);

      // .......................................................................
      test('should show all sub commands', () async {
        // Iterate all files in lib/src/commands
        // and check if they are added to the command runner
        // and if they are added to the help message
        final subCommandsDart =
            Directory('lib/src/commands').listSync(recursive: false).where(
                  (file) => file.path.endsWith('.dart'),
                );

        await capturePrint(
          ggLog: messages.add,
          code: () async => await runner.run(['ggGit', '--help']),
        );

        for (final dartFile in subCommandsDart) {
          final fileName = basename(dartFile.path);
          final subCommand = fileName
              .replaceAll('.dart', '')
              .replaceAll('_', '-')
              .replaceAll('gg-', '');

          // Check if the command has the right name
          final fileContent = await File(dartFile.path).readAsString();
          final hasRightName = fileContent.contains('name: \'$subCommand\'') ||
              fileContent.contains('name = \'$subCommand\'');
          expect(
            hasRightName,
            isTrue,
            reason: '\nPlease open "$fileName" '
                'and make sure the name is "$subCommand".',
          );

          // Make sure the command is listed within the main command
          final ggSubCommand = subCommand.pascalCase;

          expect(
            hasLog(messages, subCommand),
            isTrue,
            reason: '\nMissing subcommand "$ggSubCommand"\n'
                'Please open  "lib/src/gg_git.dart"\n'
                '"and add "addSubcommand($ggSubCommand(ggLog: ggLog));"\n'
                'Make sure the name of the command is '
                '"$subCommand".',
          );
        }
      });
    });
  });
}
