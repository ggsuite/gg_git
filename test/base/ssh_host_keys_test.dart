// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  // The RSA key of ssh.dev.azure.com, split into chunks of base64.
  final azureLine = [
    'ssh.dev.azure.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJ',
    'OfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk',
    '6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgz',
    'IZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyN',
    'LHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBm',
    'ly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H',
  ].join();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ssh_host_keys_test_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('SshHostKey', () {
    test('reads type and key from a known_hosts line', () {
      final key = SshHostKey.fromLine('  host ssh-ed25519 AAAA comment  ');
      expect(key.line, 'host ssh-ed25519 AAAA comment');
      expect(key.type, 'ssh-ed25519');
      expect(key.key, 'AAAA');
    });

    test('throws for a line that is no known_hosts line', () {
      expect(
        () => SshHostKey.fromLine('host ssh-rsa'),
        throwsA(isA<FormatException>()),
      );
    });

    test('computes the fingerprint ssh-keygen -l prints', () {
      expect(
        SshHostKey.example.fingerprint,
        'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
      );
      expect(
        SshHostKey.fromLine(azureLine).fingerprint,
        'SHA256:ohD8VZEXGWo6Ez8GSEJQ9WpafgLFsOfLOtGGQCQo6Og',
      );
    });

    test('names the key type like ssh-keygen -l', () {
      String name(String type) => SshHostKey.fromLine('h $type AAAA').typeName;
      expect(name('ssh-rsa'), 'RSA');
      expect(name('ssh-ed25519'), 'ED25519');
      expect(name('ecdsa-sha2-nistp256'), 'ECDSA');
      expect(name('ssh-dss'), 'ssh-dss');
    });
  });

  group('SshHostKeys', () {
    group('classifies the stderr of git', () {
      const unknown =
          'No ED25519 host key is known for github.com and you have '
          'requested strict checking.\r\nHost key verification failed.\r\n'
          'fatal: Could not read from remote repository.';
      const changed =
          '@@@@@\r\n@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @'
          '\r\nHost key verification failed.';
      const rejected =
          'git@ssh.dev.azure.com: Permission denied (publickey).\r\n'
          'fatal: Could not read from remote repository.';

      test('isUnknownHost', () {
        expect(SshHostKeys.isUnknownHost(unknown), isTrue);
        expect(SshHostKeys.isUnknownHost(changed), isFalse);
        expect(SshHostKeys.isUnknownHost(rejected), isFalse);
      });

      test('isChangedHostKey', () {
        expect(SshHostKeys.isChangedHostKey(changed), isTrue);
        expect(SshHostKeys.isChangedHostKey(unknown), isFalse);
      });

      test('isSetupProblem', () {
        expect(SshHostKeys.isSetupProblem(unknown), isTrue);
        expect(SshHostKeys.isSetupProblem(changed), isTrue);
        expect(SshHostKeys.isSetupProblem(rejected), isTrue);
        expect(SshHostKeys.isSetupProblem('Repository not found.'), isFalse);
      });

      test('isKeyRejected', () {
        expect(SshHostKeys.isKeyRejected(rejected), isTrue);
        expect(SshHostKeys.isKeyRejected(unknown), isFalse);
      });
    });

    group('setupHint', () {
      const unknown = 'Host key verification failed.';

      test('explains an unknown host', () {
        expect(
          SshHostKeys.setupHint('git@github.com:org/repo.git', unknown),
          'SSH does not know github.com yet. Run "git ls-remote '
          'git@github.com:org/repo.git" once, compare the fingerprint ssh '
          'shows with the one the host publishes and answer yes. Then run '
          'the command again.',
        );
        expect(
          SshHostKeys.setupHint('https://github.com/org/repo.git', unknown),
          startsWith('SSH does not know the host yet.'),
        );
      });

      test('says when ssh reads another known_hosts file', () {
        expect(
          SshHostKeys.setupHint(
            'git@github.com:org/repo.git',
            unknown,
            keyAddedTo: 'known_hosts',
          ),
          startsWith(
            'The key of github.com was added to known_hosts, but ssh still '
            'does not know the host',
          ),
        );
      });

      test('explains a changed host key', () {
        const changed =
            '@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! @\n$unknown';
        expect(
          SshHostKeys.setupHint('git@github.com:org/repo.git', changed),
          allOf(
            contains('The key of github.com differs'),
            contains('"ssh-keygen -R github.com"'),
          ),
        );
        // A host with a port is quoted for ssh-keygen.
        expect(
          SshHostKeys.setupHint('ssh://git@example.com:2222/r.git', changed),
          contains(""""ssh-keygen -R '[example.com]:2222'"."""),
        );
      });

      test('explains a refused key per host', () {
        const refused = 'Permission denied (publickey).';
        expect(
          SshHostKeys.setupHint('git@ssh.dev.azure.com:v3/o/p/r', refused),
          allOf(
            contains('ssh.dev.azure.com refused your SSH key.'),
            contains('"ssh-keygen -t rsa -b 4096"'),
            contains('Azure DevOps: User settings → SSH public keys'),
          ),
        );
        expect(
          SshHostKeys.setupHint('git@github.com:org/repo.git', refused),
          allOf(
            contains('"ssh-keygen -t ed25519"'),
            contains('GitHub: Settings → SSH and GPG keys'),
          ),
        );
        expect(
          SshHostKeys.setupHint('git@example.com:repo.git', refused),
          contains('the settings of your account on example.com'),
        );
      });

      test('is null for other failures', () {
        expect(
          SshHostKeys.setupHint('git@github.com:o/r.git', 'not found'),
          isNull,
        );
      });
    });

    group('hostOf', () {
      test('reads the host of an scp-like url', () {
        expect(
          SshHostKeys.hostOf('git@ssh.dev.azure.com:v3/org/project/repo'),
          'ssh.dev.azure.com',
        );
        expect(SshHostKeys.hostOf('github.com:ggsuite/gg.git'), 'github.com');
      });

      test('reads the host of an ssh:// url', () {
        expect(
          SshHostKeys.hostOf('ssh://git@github.com/ggsuite/gg.git'),
          'github.com',
        );
        expect(
          SshHostKeys.hostOf('git+ssh://git@github.com:22/ggsuite/gg.git'),
          'github.com',
        );
      });

      test('writes another port than 22 like known_hosts', () {
        expect(
          SshHostKeys.hostOf('ssh://git@example.com:2222/repo.git'),
          '[example.com]:2222',
        );
      });

      test('returns null for urls without ssh', () {
        expect(SshHostKeys.hostOf('https://github.com/ggsuite/gg.git'), isNull);
        expect(SshHostKeys.hostOf('file:///c/repos/gg'), isNull);
        expect(SshHostKeys.hostOf(r'C:\repos\gg'), isNull);
        expect(SshHostKeys.hostOf('/home/me/repos/gg'), isNull);
        expect(SshHostKeys.hostOf('ssh:///repo'), isNull);
      });
    });

    group('checkFingerprint', () {
      test('matches the published fingerprint', () {
        expect(
          SshHostKeys.checkFingerprint('github.com', SshHostKey.example),
          FingerprintCheck.matches,
        );
        expect(
          SshHostKeys.checkFingerprint(
            'ssh.dev.azure.com',
            SshHostKey.fromLine(azureLine),
          ),
          FingerprintCheck.matches,
        );
      });

      test('reports a fingerprint that differs from the published ones', () {
        expect(
          SshHostKeys.checkFingerprint('ssh.dev.azure.com', SshHostKey.example),
          FingerprintCheck.differs,
        );
      });

      test('reports a host without published fingerprints', () {
        expect(
          SshHostKeys.checkFingerprint('example.com', SshHostKey.example),
          FingerprintCheck.unknown,
        );
      });
    });

    group('scan', () {
      /// A git that answers `config --get core.sshCommand` with
      /// [configured] and, for `ls-remote`, does what ssh does: writes the
      /// example key into the known_hosts file named by GIT_SSH_COMMAND.
      (ProcessRunner, List<List<String>>, List<String>) fakeGit({
        String configured = '',
      }) {
        final calls = <List<String>>[];
        final sshCommands = <String>[];
        Future<ProcessResult> run(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = true,
        }) async {
          calls.add([executable, ...arguments]);
          if (arguments.first == 'config') {
            return ProcessResult(0, configured.isEmpty ? 1 : 0, configured, '');
          }
          final sshCommand = environment!['GIT_SSH_COMMAND']!;
          sshCommands.add(sshCommand);
          final path = RegExp(r'UserKnownHostsFile="([^"]+)"')
              .firstMatch(sshCommand)!
              .group(1)!;
          File(path).writeAsStringSync('${SshHostKey.example.line}\n');
          return ProcessResult(0, 128, '', 'Permission denied');
        }

        return (run, calls, sshCommands);
      }

      test('reads the key ssh accepted into its own known_hosts', () async {
        final (run, calls, sshCommands) = fakeGit();
        final hostKeys = SshHostKeys(
          knownHostsPath: p.join(tmp.path, 'known_hosts'),
          processRunner: run,
          environment: {},
        );

        final keys = await hostKeys.scan('git@github.com:ggsuite/gg.git');

        expect(calls, [
          ['git', 'config', '--get', 'core.sshCommand'],
          ['git', 'ls-remote', 'git@github.com:ggsuite/gg.git', 'HEAD'],
        ]);
        final sshCommand = sshCommands.single;
        expect(
          sshCommand,
          startsWith('ssh -o StrictHostKeyChecking=accept-new'),
        );
        expect(sshCommand, contains('BatchMode=yes'));
        // Double quotes for ssh, single quotes for sh, no backslashes.
        expect(sshCommand, contains("-o 'UserKnownHostsFile=\""));
        expect(sshCommand, isNot(contains(r'\')));
        expect(keys.single.line, SshHostKey.example.line);
        // The user's known_hosts file is not touched.
        expect(File(p.join(tmp.path, 'known_hosts')).existsSync(), isFalse);
      });

      test('uses the ssh command of GIT_SSH_COMMAND', () async {
        final (run, calls, sshCommands) = fakeGit(configured: 'ssh -F cfg');
        final hostKeys = SshHostKeys(
          processRunner: run,
          environment: {'GIT_SSH_COMMAND': ' ssh -p 2222 '},
        );

        await hostKeys.scan('git@github.com:ggsuite/gg.git');

        expect(sshCommands.single, startsWith('ssh -p 2222 -o '));
        expect(calls.where((c) => c[1] == 'config'), isEmpty);
      });

      test('uses the ssh command of core.sshCommand', () async {
        final (run, _, sshCommands) = fakeGit(configured: 'ssh -F cfg\n');
        final hostKeys = SshHostKeys(processRunner: run, environment: {});

        await hostKeys.scan('git@github.com:ggsuite/gg.git');

        expect(sshCommands.single, startsWith('ssh -F cfg -o '));
      });

      test('returns no key when the host was not reached', () async {
        final hostKeys = SshHostKeys(
          environment: {},
          processRunner: (
            executable,
            arguments, {
            workingDirectory,
            environment,
            runInShell = true,
          }) async => ProcessResult(0, 128, '', 'Could not resolve host'),
        );

        expect(await hostKeys.scan('git@nohost.invalid:repo'), isEmpty);
      });
    });

    group('trust', () {
      test('creates the known_hosts file and its folder', () {
        final path = p.join(tmp.path, '.ssh', 'known_hosts');
        SshHostKeys(knownHostsPath: path).trust([SshHostKey.example]);
        expect(File(path).readAsStringSync(), '${SshHostKey.example.line}\n');
      });

      test('appends to an existing file, also without a final newline', () {
        final path = p.join(tmp.path, 'known_hosts');
        File(path).writeAsStringSync('other ssh-rsa AAAA');
        final hostKeys = SshHostKeys(knownHostsPath: path);

        hostKeys.trust([SshHostKey.example]);
        hostKeys.trust([SshHostKey.fromLine(azureLine)]);

        expect(
          File(path).readAsStringSync(),
          'other ssh-rsa AAAA\n${SshHostKey.example.line}\n$azureLine\n',
        );
      });

      test('does not add a key the file holds already', () {
        final path = p.join(tmp.path, 'known_hosts');
        File(path).writeAsStringSync('${SshHostKey.example.line}\n');
        final hostKeys = SshHostKeys(knownHostsPath: path);

        hostKeys.trust([SshHostKey.example]);
        hostKeys.trust([SshHostKey.example, SshHostKey.fromLine(azureLine)]);

        expect(
          File(path).readAsStringSync(),
          '${SshHostKey.example.line}\n$azureLine\n',
        );
      });
    });

    test('parseKnownHosts skips comments and blank lines', () {
      final keys = SshHostKeys.parseKnownHosts(
        '# comment\n\n${SshHostKey.example.line}\r\n  \n$azureLine',
      );
      expect(keys.map((k) => k.type), ['ssh-ed25519', 'ssh-rsa']);
    });

    group('defaultKnownHostsPath', () {
      test('takes the home folder the way Git for Windows does', () {
        String path(Map<String, String> env, {bool exists = true}) =>
            SshHostKeys.defaultKnownHostsPath(
              environment: env,
              directoryExists: (_) => exists,
            );
        const all = {
          'HOME': 'home',
          'HOMEDRIVE': 'H:',
          'HOMEPATH': r'\me',
          'USERPROFILE': 'profile',
        };

        expect(path(all), p.join('home', '.ssh', 'known_hosts'));
        expect(
          path({...all}..remove('HOME')),
          p.join(r'H:\me', '.ssh', 'known_hosts'),
        );
        expect(
          path({...all}..remove('HOME'), exists: false),
          p.join('profile', '.ssh', 'known_hosts'),
        );
        expect(
          path({'HOMEDRIVE': 'H:', 'USERPROFILE': 'profile'}),
          p.join('profile', '.ssh', 'known_hosts'),
        );
        expect(path({}), p.join('.ssh', 'known_hosts'));
      });

      test('checks whether the HOMEDRIVE folder exists', () {
        expect(
          SshHostKeys.defaultKnownHostsPath(
            environment: {
              'HOMEDRIVE': tmp.path,
              'HOMEPATH': '',
              'USERPROFILE': 'profile',
            },
          ),
          p.join(tmp.path, '.ssh', 'known_hosts'),
        );
      });

      test('is used by default', () {
        expect(
          SshHostKeys().knownHostsPath,
          SshHostKeys.defaultKnownHostsPath(),
        );
      });
    });
  });
}
