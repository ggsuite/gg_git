// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

// coverage:ignore-file

// .............................................................................
/// Initializes a test directory
Directory initTestDir() {
  final tmpBase =
      Directory('/tmp').existsSync() ? Directory('/tmp') : Directory.systemTemp;

  final tmp = tmpBase.createTempSync('gg_git_test');

  final testDir = Directory('${tmp.path}/test');
  if (testDir.existsSync()) {
    testDir.deleteSync(recursive: true);
  }
  testDir.createSync(recursive: true);

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

  final result2 = await Process.run(
    'git',
    ['config', 'user.email', 'githubaction@inlavigo.com'],
    workingDirectory: testDir.path,
  );

  if (result.exitCode != 0) {
    throw Exception('Could not set mail. ${result2.stderr}');
  }

  final result3 = await Process.run(
    'git',
    ['config', 'user.name', 'Github Action'],
    workingDirectory: testDir.path,
  );

  if (result.exitCode != 0) {
    throw Exception('Could not set mail. ${result3.stderr}');
  }
}

// .............................................................................
/// Init remote git repository in directory
Directory initRemoteGit(Directory testDir) {
  final remoteDir = Directory('${testDir.path}/remote');
  remoteDir.createSync(recursive: true);
  final result = Process.runSync(
    'git',
    ['init', '--bare'],
    workingDirectory: remoteDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not initialize remote git repository.');
  }

  return remoteDir;
}

// .............................................................................
/// Init local git repository in directory
Directory initLocalGit(Directory testDir) {
  final localDir = Directory('${testDir.path}/local');
  localDir.createSync(recursive: true);

  final result = Process.runSync(
    'git',
    ['init'],
    workingDirectory: localDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not initialize local git repository.');
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
void commitFile(Directory testDir, String name) {
  final result = Process.runSync(
    'git',
    ['add', name],
    workingDirectory: testDir.path,
  );
  if (result.exitCode != 0) {
    throw Exception('Could not add $name.');
  }
  final result2 = Process.runSync(
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
void addAndCommitSampleFile(Directory testDir) {
  initFile(testDir, 'sample.txt', 'sample');
  commitFile(testDir, 'sample.txt');
}

// .............................................................................
/// Update and commit sample file
Future<void> updateAndCommitSampleFile(Directory testDir) async {
  final file = File('${testDir.path}/sample.txt');
  final content = file.existsSync() ? file.readAsStringSync() : '';
  final newContent = '${content}updated';
  await File('${testDir.path}/sample.txt').writeAsString(newContent);
  commitFile(testDir, 'sample.txt');
}

// ## uncommitted.txt

// .............................................................................
/// Init uncommitted file
void initUncommitedFile(Directory testDir) =>
    initFile(testDir, 'uncommitted.txt', 'uncommitted');

// ## pubspect.yaml

// .............................................................................
/// Create a pubspec.yaml file with a version
Future<void> setPubspec(Directory testDir, {required String? version}) async {
  final file = File('${testDir.path}/pubspec.yaml');

  var content = file.existsSync()
      ? file.readAsStringSync()
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
void commitPubspec(Directory testDir) => commitFile(testDir, 'pubspec.yaml');

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
  commitPubspec(testDir);
  await setChangeLog(testDir, version: changeLog);
  commitChangeLog(testDir);

  if (gitHead != null) {
    await addTag(testDir, gitHead);
  }
}
