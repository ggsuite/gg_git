// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
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
void _throw(
  String message,
  ProcessResult result,
) {
  if (result.exitCode != 0) {
    throw Exception(
      '$message: ${result.stderr}',
    );
  }
}

// ######################
// Init Git Repos
// ######################

// .............................................................................
/// Init git repository in test directory
Future<void> initGit(Directory testDir) async => initLocalGit(testDir);

// .............................................................................
/// Init local git repository in directory
Future<void> initLocalGit(Directory testDir) async {
  _setupGitHub(testDir);

  final localDir = testDir;

  final result = await Process.run(
    'git',
    ['init', '--initial-branch=main'],
    workingDirectory: localDir.path,
  );

  _throw('Could not initialize local git repository', result);

  final result2 = await Process.run(
    'git',
    ['checkout', '-b', 'main'],
    workingDirectory: localDir.path,
  );

  _throw('Could not create main branch', result2);
}

// .............................................................................
/// Init remote git repository in directory
Future<void> initRemoteGit(Directory testDir) async {
  final remoteDir = testDir;
  await remoteDir.create(recursive: true);
  final result = await Process.run(
    'git',
    ['init', '--bare', '--initial-branch=main'],
    workingDirectory: remoteDir.path,
  );

  _throw('Could not initialize remote git repository', result);
}

// ...........................................................................
/// Adds a remote git repo to a local git repo
Future<void> addRemoteToLocal({
  required Directory local,
  required Directory remote,
}) async {
  // Add remote
  final result2 = await Process.run(
    'git',
    [
      'remote',
      'add',
      'origin',
      remote.path,
    ],
    workingDirectory: local.path,
  );

  _throw('Could not add remote to local git repository', result2);

  // Add a initial commit, otherwise no pushing is possible
  await addAndCommitSampleFile(
    local,
    fileName: 'init',
    content: 'Initial commit',
  );

  final result3 = await Process.run(
    'git',
    [
      'push',
      '--set-upstream',
      'origin',
      'main',
    ],
    workingDirectory: local.path,
  );

  _throw('Could not set up-stream', result3);
}

// .............................................................................
/// Creates a local and a remote git repository and connects them
Future<(Directory local, Directory remote)> initLocalAndRemoteGit() async {
  final local = await initTestDir();
  await initLocalGit(local);

  final remote = await initTestDir();
  await initRemoteGit(remote);
  await addRemoteToLocal(local: local, remote: remote);
  return (local, remote);
}

// .............................................................................
void _setupGitHub(Directory testDir) async {
  if (isGitHub) {
    final result2 = await Process.run(
      'git',
      ['config', '--global', 'user.email', 'githubaction@inlavigo.com'],
      workingDirectory: testDir.path,
    );

    _throw('Could not set mail', result2);

    final result3 = await Process.run(
      'git',
      ['config', '--global', 'user.name', 'Github Action'],
      workingDirectory: testDir.path,
    );

    _throw('Could not set mail', result3);
  }
}

// #############
// branches

// .............................................................................
/// Creates a branch in the git repo in testDir
Future<void> createBranch(Directory testDir, String branchName) async {
  final result = await Process.run(
    'git',
    ['checkout', '-b', branchName],
    workingDirectory: testDir.path,
  );

  _throw('Could not create branch $branchName', result);
}

// .............................................................................
/// Returns the name of the current branch in testDir
Future<String> branchName(Directory testDir) async {
  final result = await Process.run(
    'git',
    ['branch', '--show-current'],
    workingDirectory: testDir.path,
  );

  _throw('Could not get current branch name', result);

  return result.stdout.toString().trim();
}

// ######################
// Git Ignore
// ######################

// .............................................................................
/// Adds a gitignore file to the test directory
Future<void> addAndCommitGitIgnoreFile(
  Directory d, {
  String content = '',
}) =>
    addAndCommitSampleFile(d, fileName: '.gitignore', content: content);

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

  _throw('Could not add tag $tag', result);
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
Future<File> addFileWithoutCommitting(
  Directory testDir, {
  String fileName = sampleFileName,
  String content = 'Content',
}) async {
  final result = File('${testDir.path}/$fileName');
  await result.writeAsString(content);
  return result;
}

// .............................................................................
/// Commit the file with a name in the test directory
Future<void> commitFile(
  Directory testDir,
  String fileName, {
  String message = 'Commit Message',
  bool stage = true,
  bool ammend = false,
}) async {
  final nothingHasChanged = (await modifiedFiles(testDir)).isEmpty;
  if (nothingHasChanged) {
    return;
  }

  if (stage) {
    await stageFile(testDir, fileName);
  }

  final result2 = await Process.run(
    'git',
    ['commit', '-m', message, if (ammend) '--amend'],
    workingDirectory: testDir.path,
  );

  _throw('Could not commit $fileName', result2);
}

// .............................................................................
/// Commit the file with a name in the test directory
Future<void> stageFile(
  Directory testDir,
  String fileName,
) async {
  final result = await Process.run(
    'git',
    ['add', fileName],
    workingDirectory: testDir.path,
  );

  _throw('Could not stage $fileName', result);
}

// .............................................................................
/// Returns a list of modified files in the directory
Future<List<String>> modifiedFiles(Directory directory) {
  return ModifiedFiles(
    ggLog: print,
  ).get(directory: directory, ggLog: print);
}

// .............................................................................
/// Reverts all local changes in the directory
Future<void> revertLocalChanges(Directory directory) async {
  final result = await Process.run(
    'git',
    ['restore', '.'],
    workingDirectory: directory.path,
  );

  _throw('Could not restore all changes', result);
}

// .............................................................................
/// Reverts all local changes in the directory
Future<void> hardReset(Directory directory) async {
  final result = await Process.run(
    'git',
    ['reset', '--hard', 'origin/main'],
    workingDirectory: directory.path,
  );

  _throw('Could not run "git reset --hard origin main"', result);
}

// ## sample.txt

/// The name of the sample file
const String sampleFileName = 'test.txt';

// .............................................................................
/// Add and commit sample file
Future<File> addAndCommitSampleFile(
  Directory testDir, {
  String fileName = sampleFileName,
  String content = 'sample',
  String message = 'Commit Message',
}) async {
  final file = await addFileWithoutCommitting(
    testDir,
    fileName: fileName,
    content: content,
  );
  await commitFile(testDir, fileName, message: message);
  return file;
}

// .............................................................................
/// Update and commit sample file
Future<File> updateSampleFileWithoutCommitting(
  Directory testDir, {
  String fileName = sampleFileName,
  String message = 'Commit Message',
}) async {
  final file = File('${testDir.path}/$fileName');
  final content = await file.exists() ? await file.readAsString() : '';
  final newContent = '${content}updated';
  await File('${testDir.path}/$fileName').writeAsString(newContent);
  return file;
}

// .............................................................................
/// Update and commit sample file
Future<File> updateAndCommitSampleFile(
  Directory testDir, {
  String message = 'Commit Message',
  String fileName = sampleFileName,
  bool ammend = false,
}) async {
  final file = await updateSampleFileWithoutCommitting(
    testDir,
    fileName: fileName,
  );
  await commitFile(testDir, fileName, message: message, ammend: ammend);
  return file;
}

// ## pubspect.yaml

// .............................................................................
/// Create a pubspec.yaml file with a version
Future<File> addPubspecFileWithoutCommitting(
  Directory testDir, {
  required String? version,
  String? additionalContent,
}) async {
  final file = File('${testDir.path}/pubspec.yaml');

  var content = await file.exists()
      ? await file.readAsString()
      : 'name: test\nversion: $version\n';

  if (version == null) {
    content = content.replaceAll(RegExp(r'version: .*'), '');
  } else {
    content = content.replaceAll(RegExp(r'version: .*'), 'version: $version');
  }

  // Add additional content
  if (additionalContent != null) {
    if (!content.contains(additionalContent)) {
      content += additionalContent;
    }
  }

  await file.writeAsString(content);
  return file;
}

// .............................................................................
/// Commit the pubspec file
Future<void> commitPubspecFile(Directory testDir) =>
    commitFile(testDir, 'pubspec.yaml');

// .............................................................................
/// Adds and commits a pubspec file
Future<File> addAndCommitPubspecFile(
  Directory testDir, {
  String? version = '1.0.0',
}) async {
  final file = await addPubspecFileWithoutCommitting(testDir, version: version);
  await commitPubspecFile(testDir);
  return file;
}

// .............................................................................
/// Deletes and commits a file
Future<void> deleteFileAndCommit(Directory testDir, String fileName) async {
  // Delete the file
  final file = File('${testDir.path}/$fileName');
  if (await file.exists()) {
    await file.delete();
  }

  // Stage deletion
  final result0 = await Process.run(
    'git',
    ['rm', fileName],
    workingDirectory: testDir.path,
  );

  _throw('Could execute »git rm $fileName«', result0);

  // Commit deletion
  await commitFile(testDir, fileName, stage: false);
}

// ## CHANGELOG.md

// .............................................................................
/// Create a CHANGELOG.md file with a version
Future<void> addChangeLogWithoutCommitting(
  Directory testDir, {
  String? version = '1.0.0',
}) async {
  var content = '# Change log\n\n';
  if (version != null) {
    content += '## $version - 2024-04-09\n\n';
  }

  await addFileWithoutCommitting(
    testDir,
    fileName: 'CHANGELOG.md',
    content: content,
  );
}

// .............................................................................
/// Commit the changelog file
Future<void> commitChangeLog(Directory testDir) =>
    commitFile(testDir, 'CHANGELOG.md');

// ## Version files

// .............................................................................
/// Write version into pubspec.yaml, Changelog.md and add a tag
Future<void> addAndCommitVersions(
  Directory testDir, {
  required String? pubspec,
  required String? changeLog,
  required String? gitHead,
  String? appendToPubspec,
}) async {
  await addPubspecFileWithoutCommitting(
    testDir,
    version: pubspec,
    additionalContent: appendToPubspec,
  );

  await commitPubspecFile(testDir);
  await addChangeLogWithoutCommitting(testDir, version: changeLog);
  await commitChangeLog(testDir);

  if (gitHead != null) {
    await addTag(testDir, gitHead);
  }
}

// .............................................................................
/// Adds and pushes local changes
Future<void> pushLocalChanges(Directory d) async {
  // Add local changes
  final result0 = await Process.run(
    'git',
    ['add', '.'],
    workingDirectory: d.path,
  );

  _throw('Could not add local changes', result0);

  final result1 = await Process.run(
    'git',
    ['push'],
    workingDirectory: d.path,
  );

  _throw('Could not push local changes', result1);
}
