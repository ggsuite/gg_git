// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_is_github/gg_is_github.dart';

// coverage:ignore-file

// .............................................................................
/// Initializes a test directory
Future<Directory> initTestDir() async {
  final tmpBase = await Directory('/tmp').exists()
      ? Directory('/tmp')
      : Directory.systemTemp;

  final tmp = await tmpBase.createTemp('gg_git_test');

  final testDir = Directory('${tmp.path}/test');
  if (await testDir.exists()) {
    await testDir.delete(recursive: true);
  }
  await testDir.create(recursive: true);

  return testDir;
}

// .............................................................................
/// Init git repository in test directory
Future<void> initGit(Directory testDir) async {
  final result =
      await Process.run('git', ['init'], workingDirectory: testDir.path);
  if (result.exitCode != 0) {
    throw Exception('Could not initialize git repository. ${result.stderr}');
  }

  if (isGitHub) {
    final result2 = await Process.run(
      'git',
      ['config', '--global', 'user.email', 'githubaction@inlavigo.com'],
      workingDirectory: testDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception('Could not set mail. ${result2.stderr}');
    }

    final result3 = await Process.run(
      'git',
      ['config', '--global', 'user.name', 'Github Action'],
      workingDirectory: testDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception('Could not set mail. ${result3.stderr}');
    }
  }
}

// .............................................................................
/// Adds a gitignore file to the test directory
Future<void> addAndCommitGitIgnoreFile(
  Directory d, {
  String content = '',
}) =>
    addAndCommitSampleFile(d, fileName: '.gitignore', content: content);

// .............................................................................
/// Init remote git repository in directory
Future<Directory> initRemoteGit(Directory testDir) async {
  final remoteDir = Directory('${testDir.path}/remote');
  await remoteDir.create(recursive: true);
  final result = await Process.run(
    'git',
    ['init', '--bare', '--initial-branch=main'],
    workingDirectory: remoteDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not initialize remote git repository.');
  }

  return remoteDir;
}

// .............................................................................
/// Init local git repository in directory
Future<Directory> initLocalGit(Directory testDir) async {
  final localDir = Directory('${testDir.path}/local');
  await localDir.create(recursive: true);

  final result = await Process.run(
    'git',
    ['init', '--initial-branch=main'],
    workingDirectory: localDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not initialize local git repository.');
  }

  final result2 = await Process.run(
    'git',
    ['checkout', '-b', 'main'],
    workingDirectory: localDir.path,
  );

  if (result2.exitCode != 0) {
    throw Exception('Could not create main branch.');
  }

  return localDir;
}

// #############
// # Tag helpers
// #############

/// Add tag to test directory
Future<void> addTag(Directory testDir, String tag) async {
  final result = await Process.run(
    'git',
    ['tag', tag],
    workingDirectory: testDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not add tag $tag.');
  }
}

/// Add tags to test directory
Future<void> addTags(Directory testDir, List<String> tags) async {
  for (final tag in tags) {
    await addTag(testDir, tag);
  }
}

// ##############
// # File helpers
// ##############

// .............................................................................
/// Init a file with a name in the test directory
Future<void> initFile(Directory testDir, String name, String content) =>
    File('${testDir.path}/$name').writeAsString(content);

// .............................................................................
/// Commit the file with a name in the test directory
Future<void> commitFile(Directory testDir, String name) async {
  final result = await Process.run(
    'git',
    ['add', name],
    workingDirectory: testDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not add $name.');
  }
  final result2 = await Process.run(
    'git',
    ['commit', '-m', 'Initial commit'],
    workingDirectory: testDir.path,
  );
  if (result2.exitCode != 0) {
    throw Exception('Could not commit $name.');
  }
}

// ## sample.txt

// .............................................................................
/// Add and commit sample file
Future<void> addAndCommitSampleFile(
  Directory testDir, {
  String fileName = 'sample.txt',
  String content = 'sample',
}) async {
  await initFile(testDir, fileName, content);
  await commitFile(testDir, fileName);
}

// .............................................................................
/// Update and commit sample file
Future<void> updateAndCommitSampleFile(Directory testDir) async {
  final file = File('${testDir.path}/sample.txt');
  final content = await file.exists() ? file.readAsString() : '';
  final newContent = '${content}updated';
  await File('${testDir.path}/sample.txt').writeAsString(newContent);
  await commitFile(testDir, 'sample.txt');
}

// ## uncommitted.txt

// .............................................................................
/// Init uncommitted file
Future<void> initUncommittedFile(Directory testDir) =>
    initFile(testDir, 'uncommitted.txt', 'uncommitted');

// ## pubspect.yaml

// .............................................................................
/// Create a pubspec.yaml file with a version
Future<void> setPubspec(Directory testDir, {required String? version}) async {
  final file = File('${testDir.path}/pubspec.yaml');

  var content = await file.exists()
      ? await file.readAsString()
      : 'name: test\nversion: $version\n';

  if (version == null) {
    content = content.replaceAll(RegExp(r'version: .*'), '');
  } else {
    content = content.replaceAll(RegExp(r'version: .*'), 'version: $version');
  }

  await file.writeAsString(content);
}

// .............................................................................
/// Commit the pubspec file
Future<void> commitPubspec(Directory testDir) =>
    commitFile(testDir, 'pubspec.yaml');

// ## CHANGELOG.md

// .............................................................................
/// Create a CHANGELOG.md file with a version
Future<void> setChangeLog(
  Directory testDir, {
  required String? version,
}) async {
  var content = '# Change log\n\n';
  if (version != null) {
    content += '## $version\n\n';
  }

  await initFile(testDir, 'CHANGELOG.md', content);
}

// .............................................................................
/// Commit the changelog file
void commitChangeLog(Directory testDir) => commitFile(testDir, 'CHANGELOG.md');

// ## Version files

// .............................................................................
/// Write version into pubspec.yaml, Changelog.md and add a tag
Future<void> setupVersions(
  Directory testDir, {
  required String? pubspec,
  required String? changeLog,
  required String? gitHead,
}) async {
  await setPubspec(testDir, version: pubspec);
  await commitPubspec(testDir);
  await setChangeLog(testDir, version: changeLog);
  commitChangeLog(testDir);

  if (gitHead != null) {
    await addTag(testDir, gitHead);
  }
}
