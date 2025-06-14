// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:mocktail/mocktail.dart';

/// Reads the commit message of the head revision.
class HeadMessage extends GgGitBase<String> {
  // ...........................................................................
  /// Constructor
  HeadMessage({
    required super.ggLog,
    super.processWrapper,
    IsCommitted? isCommitted,
  }) : _isCommitted =
           isCommitted ??
           IsCommitted(ggLog: ggLog, processWrapper: processWrapper),
       super(
         name: 'message',
         description: 'Returns the commit message of the head revision.',
       ) {
    HeadHash.addParams(argParser);
  }

  // ...........................................................................
  @override
  Future<String> exec({
    required Directory directory,
    required GgLog ggLog,
    int? offset,
  }) async {
    offset = HeadHash.readOffset(offset, argResults);

    final result = await get(
      directory: directory,
      ggLog: ggLog,
      offset: offset,
    );
    ggLog(result);
    return result;
  }

  // ...........................................................................
  /// Returns the commit message of the head revision in the given directory.
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
    int offset = 0,
    bool throwIfNotEverythingIsCommitted = true,
  }) async {
    HeadHash.checkOffset(offset);

    await check(directory: directory);

    final isCommited = await _isCommitted.get(
      directory: directory,
      ggLog: ggLog,
    );

    if (!isCommited && throwIfNotEverythingIsCommitted) {
      throw Exception('Not everything is committed.');
    }

    // To get the commit message, the command is adjusted to use `git log`
    final offsetString = offset == 0 ? '' : '~$offset';
    final result = await processWrapper.run('git', [
      'log',
      '-1',
      '--pretty=format:%B',
      'HEAD$offsetString',
    ], workingDirectory: directory.path);

    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    } else {
      throw Exception('Could not read the head message: ${result.stderr}');
    }
  }

  // ######################
  // Private
  // ######################

  final IsCommitted _isCommitted;
}

/// Mocktail mock
class MockHeadMessage extends Mock implements HeadMessage {}
