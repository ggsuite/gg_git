// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';

// #############################################################################
/// Returns the unix timestamp of the head revision.
class HeadTimeStamp extends GgGitBase<int> {
  /// Constructor
  HeadTimeStamp({
    required super.ggLog,
    super.processWrapper,
    IsCommitted? isCommitted,
  }) : _isCommitted =
           isCommitted ??
           IsCommitted(ggLog: ggLog, processWrapper: processWrapper),
       super(
         name: 'time-stamp',
         description: 'Returns the unix timestamp of the head revision.',
       ) {
    HeadHash.addParams(argParser);
  }

  // ...........................................................................
  /// Logs the unix timestamp of the head revision in seconds.
  @override
  Future<int> exec({
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
    ggLog('$result');
    return result;
  }

  // ...........................................................................
  /// Returns the unix timestamp of the head revision in seconds.
  @override
  Future<int> get({
    required GgLog ggLog,
    required Directory directory,
    int offset = 0,
  }) async {
    HeadHash.checkOffset(offset);

    // Directory is a git repo?
    await check(directory: directory);

    // Everything is committed?
    final isCommited = await _isCommitted.get(
      directory: directory,
      ggLog: ggLog,
    );

    if (!isCommited) {
      throw Exception('Not everything is committed.');
    }

    // Read the hash
    final head = 'HEAD${offset == 0 ? '' : '~$offset'}';

    final result = await processWrapper.run('git', [
      'show',
      '-s',
      '--format=%ct',
      head,
    ], workingDirectory: directory.path);

    if (result.exitCode == 0) {
      final timeStampString = result.stdout.toString().trim();
      final timeStamp = int.parse(timeStampString);
      return timeStamp;
    } else {
      throw Exception(
        'Could not read the timestamp from head hash: ${result.stderr}',
      );
    }
  }

  // ...........................................................................
  final IsCommitted _isCommitted;
}

/// Mocktail mock
class MockHeadTimeStamp extends MockDirCommand<int> implements HeadTimeStamp {}
