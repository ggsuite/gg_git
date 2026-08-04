// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import 'test_helpers.dart';

// .............................................................................
/// Builds the content of a cached template repository in [repo].
typedef CachedRepoBuilder = Future<void> Function(Directory repo);

// .............................................................................
/// Builds the content of a cached local/remote template pair.
typedef CachedRepoPairBuilder =
    Future<void> Function(Directory local, Directory remote);

// .............................................................................
/// Copies the repo template [key] into [target].
///
/// The template is built only once per isolate (i.e. once per test file):
/// the first call with a given [key] runs [build] with a fresh template
/// directory; later calls with the same [key] skip [build] and only copy
/// the template into [target] using a pure Dart directory copy — no git
/// processes are spawned for a copy.
///
/// Contract: within one isolate a [key] must always map to the same recipe.
/// The first builder wins; later builders with the same [key] are ignored.
/// Keys starting with `gg_git/` are reserved for the helpers of this
/// package.
///
/// [target] must be empty or not existing. Template directories live in the
/// system temp directory for the lifetime of the process (similar to the
/// parent directories created by [initTestDir]).
Future<void> initCachedRepo(
  Directory target, {
  required String key,
  required CachedRepoBuilder build,
}) async {
  final template = await _memoized(
    _localTemplates,
    key,
    () => _buildLocalTemplate(key, build),
  );

  await _prepareTarget(target);
  _copyDirSync(template, target);
}

// .............................................................................
/// Returns a fresh copy of the local/remote template pair [key].
///
/// The template pair is built only once per isolate by calling [build] with
/// two fresh template directories. Every call returns a new copy of both
/// directories. When the local template has an `origin` remote, the copy's
/// `origin` is rewired to the copied remote via `git remote set-url` — the
/// only git process spawned per copy.
///
/// The same key contract as in [initCachedRepo] applies. The caller owns
/// the returned directories and should delete them in `tearDown`.
Future<(Directory local, Directory remote)> initCachedRepoPair({
  required String key,
  required CachedRepoPairBuilder build,
}) async {
  final (templateLocal, templateRemote) = await _memoized(
    _pairTemplates,
    key,
    () => _buildPairTemplate(key, build),
  );

  final local = await Directory.systemTemp.createTemp('gg_git_copy_local_');
  final remote = await Directory.systemTemp.createTemp('gg_git_copy_remote_');
  _copyDirSync(templateLocal, local);
  _copyDirSync(templateRemote, remote);

  if (_hasOriginRemote(templateLocal)) {
    final result = await Process.run('git', [
      'remote',
      'set-url',
      'origin',
      remote.path,
    ], workingDirectory: local.path);

    if (result.exitCode != 0) {
      throw Exception('Could not set remote url: ${result.stderr}');
    }
  }

  return (local, remote);
}

// .............................................................................
/// Cached variant of [initGit]: same result, but built once per isolate.
Future<void> initCachedGit(
  Directory testDir, {
  bool isEolLfEnabled = true,
}) async {
  await initCachedRepo(
    testDir,
    key: 'gg_git/initGit(isEolLfEnabled: $isEolLfEnabled)',
    build: (repo) => initGit(repo, isEolLfEnabled: isEolLfEnabled),
  );
}

// .............................................................................
/// Cached variant of [initLocalAndRemoteGit]: same result, but built once
/// per isolate. Every call returns a fresh copy with a rewired `origin`.
Future<(Directory local, Directory remote)> initCachedLocalAndRemoteGit() =>
    initCachedRepoPair(
      key: 'gg_git/initLocalAndRemoteGit',
      build: (local, remote) async {
        await initLocalGit(local);
        await initRemoteGit(remote);
        await addRemoteToLocal(local: local, remote: remote);
      },
    );

// .............................................................................
/// Adds and pushes local changes and creates an upstream branch.
Future<void> pushLocalChangesUpstream(Directory d, String branch) async {
  // Add local changes
  final result0 = await Process.run('git', [
    'add',
    '.',
  ], workingDirectory: d.path);
  _throw('Could not add local changes', result0);

  // Push and create upstream
  final result1 = await Process.run('git', [
    'push',
    '-u',
    'origin',
    branch,
  ], workingDirectory: d.path);
  _throw('Could not push local changes with upstream', result1);
}

// .............................................................................
final Map<String, Future<Directory>> _localTemplates = {};
final Map<String, Future<(Directory, Directory)>> _pairTemplates = {};

// .............................................................................
Future<T> _memoized<T>(
  Map<String, Future<T>> cache,
  String key,
  Future<T> Function() create,
) async {
  var future = cache[key];
  if (future == null) {
    future = create();
    cache[key] = future;
  }

  try {
    return await future;
  } catch (_) {
    // Do not cache failed builds: a later call retries.
    unawaited(cache.remove(key));
    rethrow;
  }
}

// .............................................................................
Future<Directory> _buildLocalTemplate(
  String key,
  CachedRepoBuilder build,
) async {
  final dir = await Directory.systemTemp.createTemp(
    'gg_git_template_${_safeKey(key)}_',
  );
  await build(dir);
  return dir;
}

// .............................................................................
Future<(Directory, Directory)> _buildPairTemplate(
  String key,
  CachedRepoPairBuilder build,
) async {
  final parent = await Directory.systemTemp.createTemp(
    'gg_git_template_${_safeKey(key)}_',
  );
  final local = Directory(join(parent.path, 'local'));
  final remote = Directory(join(parent.path, 'remote'));
  await local.create();
  await remote.create();
  await build(local, remote);
  return (local, remote);
}

// .............................................................................
String _safeKey(String key) => key.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');

// .............................................................................
bool _hasOriginRemote(Directory repo) {
  final config = File(join(repo.path, '.git', 'config'));
  if (!config.existsSync()) {
    return false;
  }
  return config.readAsStringSync().contains('[remote "origin"]');
}

// .............................................................................
Future<void> _prepareTarget(Directory target) async {
  if (await target.exists()) {
    final isEmpty = await target.list().isEmpty;
    if (!isEmpty) {
      throw ArgumentError('Target directory ${target.path} must be empty.');
    }
  } else {
    await target.create(recursive: true);
  }
}

// .............................................................................
void _copyDirSync(Directory source, Directory target) {
  target.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final newPath = join(target.path, basename(entity.path));
    if (entity is File) {
      entity.copySync(newPath);
    } else if (entity is Directory) {
      _copyDirSync(entity, Directory(newPath));
    }
  }
}

// .............................................................................
void _throw(String message, ProcessResult result) {
  if (result.exitCode != 0) {
    throw Exception('$message: ${result.stderr}');
  }
}
