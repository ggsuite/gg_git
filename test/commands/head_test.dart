// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/src/commands/head.dart';
import 'package:path/path.dart';
import 'package:recase/recase.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];

  // Iterate all files in lib/src/commands
  // and check if they are added to the command runner
  // and if they are added to the help message
  final subCommands = Directory('lib/src/commands/head')
      .listSync(recursive: false)
      .where((file) => file.path.endsWith('.dart'))
      .map(
        (e) => basename(e.path)
            .replaceAll('.dart', '')
            .replaceAll('_', '-')
            .replaceAll('gg-', '')
            .replaceAll('head-', ''),
      )
      .toList();

  setUp(() {
    messages.clear();
  });

  group('Head', () {
    // #########################################################################
    group('Cli', () {
      final ggGit = GgGit(ggLog: (msg) => messages.add(msg));

      final CommandRunner<void> runner = CommandRunner<void>(
        'ggGit',
        'Description goes here.',
      )..addCommand(ggGit);

      // .......................................................................
      test('should show all sub commands', () async {
        await capturePrint(
          ggLog: messages.add,
          code: () async => await runner.run(['ggGit', 'head', '--help']),
        );

        for (final subCommand in subCommands) {
          final ggSubCommand = subCommand.pascalCase;

          expect(
            hasLog(messages, subCommand),
            isTrue,
            reason:
                '\nMissing subcommand "$ggSubCommand"\n'
                'Please open  "lib/src/gg_git.dart" and add\n'
                '"addSubcommand($ggSubCommand(ggLog: ggLog));',
          );
        }
      });
    });

    group('Class', () {
      test('should work fine', () {
        final head = Head(ggLog: messages.add);

        expect(head.name, 'head');
        expect(
          head.description,
          'Commands for retrieving information about the head revision.',
        );

        for (final subCommand in subCommands) {
          final ggSubCommand = subCommand.pascalCase;

          expect(
            head.subcommands.keys.contains(subCommand),
            isTrue,
            reason:
                '\nMissing subcommand "$ggSubCommand"\n'
                'Please open  "lib/src/commands/head.dart" and add\n'
                '"addSubcommand($ggSubCommand(ggLog: ggLog));',
          );
        }
      });
    });
  });
}
