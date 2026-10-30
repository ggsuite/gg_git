// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'process_runner.dart';

/// How the fingerprint of a host key compares to the fingerprints the
/// operator of the host publishes.
enum FingerprintCheck {
  /// The fingerprint is one of the published ones.
  matches,

  /// The host publishes fingerprints, but this one is none of them.
  differs,

  /// No published fingerprints are known for the host.
  unknown,
}

// .............................................................................
/// A key an ssh server presented, as one line of a known_hosts file.
class SshHostKey {
  /// Creates the key from one [line] of a known_hosts file:
  /// `<host> <key type> <base64 key> [comment]`.
  factory SshHostKey.fromLine(String line) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 3) {
      throw FormatException('Not a known_hosts line: "$line"');
    }
    return SshHostKey._(line.trim(), fields[1], fields[2]);
  }

  const SshHostKey._(this.line, this.type, this.key);

  /// The line of the known_hosts file.
  final String line;

  /// The key type, e.g. `ssh-ed25519`.
  final String type;

  /// The key, base64 encoded.
  final String key;

  /// The fingerprint as `ssh-keygen -l` prints it: `SHA256:<base64>`.
  String get fingerprint {
    final digest = sha256.convert(base64.decode(key));
    final encoded = base64.encode(digest.bytes).replaceAll('=', '');
    return 'SHA256:$encoded';
  }

  /// The short name of the key type `ssh-keygen -l` prints, e.g. `ED25519`.
  String get typeName {
    if (type == 'ssh-rsa') return 'RSA';
    if (type == 'ssh-ed25519') return 'ED25519';
    if (type.startsWith('ecdsa-')) return 'ECDSA';
    return type;
  }

  /// An example key: the ED25519 key of github.com.
  static final SshHostKey example = SshHostKey.fromLine(
    'github.com ssh-ed25519 '
    'AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl',
  );
}

// .............................................................................
/// Finds out why an ssh connection of git failed, reads the key an unknown
/// host presents and adds it to the known_hosts file.
class SshHostKeys {
  /// Constructor. [processRunner] runs git, [knownHostsPath] is the
  /// known_hosts file [trust] writes to, [environment] is where a
  /// `GIT_SSH_COMMAND` of the user is looked up.
  SshHostKeys({
    ProcessRunner? processRunner,
    this._knownHostsPath,
    Map<String, String>? environment,
  }) : _processRunner = processRunner ?? defaultProcessRunner,
       _environment = environment ?? Platform.environment;

  /// The known_hosts file [trust] adds keys to. Found only when needed:
  /// [defaultKnownHostsPath] may look at a network home folder.
  late final String knownHostsPath = _knownHostsPath ?? defaultKnownHostsPath();

  // ...........................................................................
  /// Whether [stderr] shows that ssh does not know the host yet. A host
  /// whose known key changed is not unknown, see [isChangedHostKey].
  static bool isUnknownHost(String stderr) {
    final text = stderr.toLowerCase();
    return text.contains('host key verification failed') &&
        !isChangedHostKey(stderr);
  }

  /// Whether [stderr] shows that the host presents another key than the one
  /// in the known_hosts file.
  static bool isChangedHostKey(String stderr) =>
      stderr.toLowerCase().contains('remote host identification has changed');

  /// Whether [stderr] shows that the host refused the ssh key of the user.
  static bool isKeyRejected(String stderr) =>
      stderr.toLowerCase().contains('permission denied (publickey');

  /// Whether [stderr] shows that ssh is not set up for the host: unknown,
  /// changed host key or refused user key — the cases [setupHint] explains.
  static bool isSetupProblem(String stderr) =>
      isUnknownHost(stderr) ||
      isChangedHostKey(stderr) ||
      isKeyRejected(stderr);

  // ...........................................................................
  /// What the developer does next when [stderr] of a git command on
  /// [repoUrl] shows that ssh is not set up for its host. Null for every
  /// other failure. [keyAddedTo] is the known_hosts file the key of an
  /// unknown host was just added to.
  static String? setupHint(
    String repoUrl,
    String stderr, {
    String? keyAddedTo,
  }) {
    final host = hostOf(repoUrl) ?? 'the host';
    final lsRemote = 'Run "git ls-remote $repoUrl" once';
    if (isUnknownHost(stderr)) {
      return keyAddedTo != null
          ? 'The key of $host was added to $keyAddedTo, but ssh still does '
                'not know the host: it reads another known_hosts file '
                '(UserKnownHostsFile in ~/.ssh/config?). $lsRemote and '
                'answer yes. Then run the command again.'
          : 'SSH does not know $host yet. $lsRemote, compare the '
                'fingerprint ssh shows with the one the host publishes and '
                'answer yes. Then run the command again.';
    }
    if (isChangedHostKey(stderr)) {
      // A [host]:port name is quoted, or zsh takes the brackets as a glob.
      final quoted = host.startsWith('[') ? "'$host'" : host;
      return 'The key of $host differs from the one in your known_hosts '
          'file: either the host changed its key, or someone intercepts the '
          'connection. Compare the new key with the fingerprint the host '
          'publishes, then remove the old one with "ssh-keygen -R $quoted".';
    }
    if (isKeyRejected(stderr)) {
      // Azure DevOps takes RSA keys only.
      final azure = _azureHosts.contains(host);
      final keyType = azure ? 'rsa -b 4096' : 'ed25519';
      final where = azure
          ? 'Azure DevOps: User settings → SSH public keys'
          : host == 'github.com'
          ? 'GitHub: Settings → SSH and GPG keys'
          : 'the settings of your account on $host';
      return '$host refused your SSH key. If you have none yet, create one '
          'with "ssh-keygen -t $keyType". Then add the public key '
          '(~/.ssh/*.pub) in $where and run the command again.';
    }
    return null;
  }

  // ...........................................................................
  /// The host [repoUrl] connects to over ssh, as the known_hosts file names
  /// it: `host`, or `[host]:port` for a port other than 22. Null when the
  /// url does not use ssh.
  static String? hostOf(String repoUrl) {
    final url = repoUrl.trim();
    final scheme = RegExp(r'^([a-z][a-z0-9+.-]*)://').firstMatch(url);
    if (scheme != null) {
      if (!scheme.group(1)!.split('+').contains('ssh')) {
        return null;
      }
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        return null;
      }
      return uri.hasPort && uri.port != 22
          ? '[${uri.host}]:${uri.port}'
          : uri.host;
    }

    // scp-like syntax: [user@]host:path. A single letter before the colon
    // is a Windows drive, not a host.
    final scpLike = RegExp(r'^(?:[^@/\\]+@)?([^:/\\@]{2,}):').firstMatch(url);
    return scpLike?.group(1);
  }

  // ...........................................................................
  /// Compares the fingerprint of [key] with the fingerprints the operator
  /// of [host] publishes, see [publishedFingerprints].
  static FingerprintCheck checkFingerprint(String host, SshHostKey key) {
    final published = publishedFingerprints[host];
    if (published == null) {
      return FingerprintCheck.unknown;
    }
    return published.contains(key.fingerprint)
        ? FingerprintCheck.matches
        : FingerprintCheck.differs;
  }

  /// The fingerprints the operators of well-known git hosts publish.
  ///
  /// - github.com: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
  /// - Azure DevOps: https://learn.microsoft.com/en-us/azure/devops/repos/git/use-ssh-keys-to-authenticate
  static const Map<String, Set<String>> publishedFingerprints = {
    'github.com': {
      'SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s',
      'SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM',
      'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU',
    },
    'ssh.dev.azure.com': _azureFingerprints,
    'vs-ssh.visualstudio.com': _azureFingerprints,
  };

  static const _azureFingerprints = {
    'SHA256:ohD8VZEXGWo6Ez8GSEJQ9WpafgLFsOfLOtGGQCQo6Og',
  };

  /// The ssh hosts of Azure DevOps.
  static const _azureHosts = {'ssh.dev.azure.com', 'vs-ssh.visualstudio.com'};

  // ...........................................................................
  /// Reads the keys the host of [repoUrl] presents, without trusting them.
  ///
  /// Runs `git ls-remote` with the ssh command git uses — the user's
  /// `GIT_SSH_COMMAND` or `core.sshCommand`, else `ssh` — told to accept the
  /// host key into an empty known_hosts file of its own. So the key is read
  /// by the same ssh and ssh config as a clone. The user's known_hosts file
  /// stays untouched. Returns an empty list when the host could not be
  /// reached.
  Future<List<SshHostKey>> scan(String repoUrl) async {
    final sshCommand = await _sshCommand();
    final dir = Directory.systemTemp.createTempSync('gg_ssh_host_keys_');
    try {
      final knownHosts = File(p.join(dir.path, 'known_hosts'))..createSync();
      // git runs GIT_SSH_COMMAND through sh, which wants forward slashes.
      // ssh splits the value of UserKnownHostsFile at spaces unless it is
      // in double quotes; the single quotes around it are for sh.
      final path = knownHosts.path.replaceAll(r'\', '/');
      final options = [
        '-o StrictHostKeyChecking=accept-new',
        '-o ${_shQuote('UserKnownHostsFile="$path"')}',
        '-o BatchMode=yes',
        '-o ConnectTimeout=20',
      ];
      await _processRunner(
        'git',
        // HEAD only: the key is wanted, not the refs of the repository.
        ['ls-remote', repoUrl, 'HEAD'],
        environment: {'GIT_SSH_COMMAND': '$sshCommand ${options.join(' ')}'},
      );
      return parseKnownHosts(knownHosts.readAsStringSync());
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  // ...........................................................................
  /// Adds [keys] to the known_hosts file, creating it when needed. A key
  /// the file holds already is not added a second time.
  void trust(List<SshHostKey> keys) {
    final file = File(knownHostsPath);
    file.parent.createSync(recursive: true);
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    final present = {
      for (final line in const LineSplitter().convert(existing)) line.trim(),
    };
    final lines = [
      for (final key in keys)
        if (!present.contains(key.line)) '${key.line}\n',
    ].join();
    if (lines.isEmpty) {
      return;
    }
    final separator = existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
    file.writeAsStringSync('$separator$lines', mode: FileMode.append);
  }

  // ...........................................................................
  /// The keys in the known_hosts file [content]; comments and blank lines
  /// are skipped.
  static List<SshHostKey> parseKnownHosts(String content) => [
    for (final line in const LineSplitter().convert(content))
      if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
        SshHostKey.fromLine(line),
  ];

  /// The known_hosts file ssh reads by default: `~/.ssh/known_hosts`.
  ///
  /// The home folder is found the way Git for Windows finds it for its ssh:
  /// HOME, else HOMEDRIVE + HOMEPATH when that folder exists — a network
  /// home on many company machines —, else USERPROFILE.
  static String defaultKnownHostsPath({
    Map<String, String>? environment,
    bool Function(String path)? directoryExists,
  }) {
    final env = environment ?? Platform.environment;
    final exists = directoryExists ?? (path) => Directory(path).existsSync();
    String knownHosts(String home) => p.join(home, '.ssh', 'known_hosts');

    final home = env['HOME'];
    if (home != null) {
      return knownHosts(home);
    }
    final drive = env['HOMEDRIVE'];
    final homePath = env['HOMEPATH'];
    if (drive != null && homePath != null && exists('$drive$homePath')) {
      return knownHosts('$drive$homePath');
    }
    return knownHosts(env['USERPROFILE'] ?? '');
  }

  // ######################
  // Private
  // ######################

  final ProcessRunner _processRunner;
  final Map<String, String> _environment;
  final String? _knownHostsPath;

  /// The ssh command git runs: GIT_SSH_COMMAND, else core.sshCommand, else
  /// plain `ssh`.
  Future<String> _sshCommand() async {
    final fromEnvironment = _environment['GIT_SSH_COMMAND']?.trim() ?? '';
    if (fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }
    final config = await _processRunner('git', [
      'config',
      '--get',
      'core.sshCommand',
    ]);
    final fromConfig = config.exitCode == 0 ? '${config.stdout}'.trim() : '';
    return fromConfig.isNotEmpty ? fromConfig : 'ssh';
  }

  /// Quotes [value] as one word for sh.
  static String _shQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}

/// Mock for [SshHostKeys].
class MockSshHostKeys extends Mock implements SshHostKeys {}
