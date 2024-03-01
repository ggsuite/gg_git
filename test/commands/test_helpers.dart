// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// .............................................................................
import 'dart:io';

// .............................................................................
Future<void> writeFile(File file, String content) async {
  file.writeAsStringSync(content, flush: true);
  // await Future<void>.delayed(const Duration(microseconds: 5));
}

// .............................................................................
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
Future<void> initGit(Directory testDir) async {
  final result =
      await Process.run('git', ['init'], workingDirectory: testDir.path);
  if (result.exitCode != 0) {
    throw Exception('Could not initialize git repository.');
  }
}

// .............................................................................
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

Future<void> addTags(Directory testDir, List<String> tags) async {
  for (final tag in tags) {
    await addTag(testDir, tag);
  }
}

// ##############
// # File helpers
// ##############

// .............................................................................
Future<void> initFile(Directory testDir, String name, String content) =>
    writeFile(File('${testDir.path}/$name'), content);

// .............................................................................
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
void addAndCommitSampleFile(Directory testDir) {
  initFile(testDir, 'sample.txt', 'sample');
  commitFile(testDir, 'sample.txt');
}

// .............................................................................
Future<void> updateAndCommitSampleFile(Directory testDir) async {
  final file = File('${testDir.path}/sample.txt');
  final content = file.existsSync() ? file.readAsStringSync() : '';
  final newContent = '${content}updated';
  await writeFile(File('${testDir.path}/sample.txt'), newContent);
  commitFile(testDir, 'sample.txt');
}

// ## uncommitted.txt

// .............................................................................
void initUncommitedFile(Directory testDir) =>
    initFile(testDir, 'uncommitted.txt', 'uncommitted');

// ## pubspect.yaml

// .............................................................................
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

  await writeFile(file, content);
}

// .............................................................................
void commitPubspec(Directory testDir) => commitFile(testDir, 'pubspec.yaml');

// ## CHANGELOG.md

// .............................................................................
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

// ## Version files

// .............................................................................
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

// .............................................................................
void commitChangeLog(Directory testDir) => commitFile(testDir, 'CHANGELOG.md');
