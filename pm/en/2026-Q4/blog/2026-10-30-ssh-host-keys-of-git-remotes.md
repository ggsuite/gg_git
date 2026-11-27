<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# SSH host keys of git remotes

## Motivation

- On a new machine, the first git command against an ssh remote fails:
  ssh does not know the host yet and stops with »Host key verification
  failed«.
- The same words also appear when a known host suddenly presents another
  key – a key rotation or an attack. Only the first case may be fixed by
  trusting the key.
- Tools built on gg_git need to tell these cases apart, show the key a
  host presents and store it once the user trusts it – without guessing
  which ssh and which known_hosts file git uses.

## Strategy

- One class, `SshHostKeys`, next to `GitRetry`: both deal with the
  transport of git, not with a repository.
- Classify the stderr of git instead of running ssh separately.
- Read the host key with git itself, so the ssh and the ssh config of a
  real clone are used.
- Compute fingerprints in Dart and compare them with the ones GitHub and
  Azure DevOps publish.
- Never write to the user's known_hosts file except in `trust`.

## Classifying the failure

- `isUnknownHost`: »Host key verification failed« without a changed key.
- `isChangedHostKey`: »REMOTE HOST IDENTIFICATION HAS CHANGED«.
- `isKeyRejected`: »Permission denied (publickey)«.
- `setupHint` turns each case into the next step: `git ls-remote <url>`
  for an unknown host, `ssh-keygen -R <host>` for a changed key, and for a
  refused key the key type and the settings page of the host (Azure DevOps
  takes RSA keys only).
- `hostOf` reads the host as known_hosts names it: `host`, or
  `[host]:port` for another port than 22.

## Reading the key

- `scan` runs `git ls-remote <url> HEAD` with a `GIT_SSH_COMMAND` that
  accepts the key into an empty known_hosts file of its own.
- The command starts from the user's own ssh command – `GIT_SSH_COMMAND`,
  `core.sshCommand`, else `ssh` – so proxies and ssh configs keep working.
  Git for Windows bundles its own ssh; `ssh-keyscan` is often not on the
  PATH there.
- The temp path is quoted twice: double quotes for ssh, which splits the
  value at spaces, single quotes for sh.
- `SshHostKey.fingerprint` is the SHA256 of the key, as `ssh-keygen -l`
  prints it; `checkFingerprint` answers `matches`, `differs` or `unknown`.

## Storing the key

- `trust` appends to `~/.ssh/known_hosts` and skips lines already there.
- The home folder is found like Git for Windows finds it: HOME, else
  HOMEDRIVE + HOMEPATH when that folder exists, else USERPROFILE.
- The path is resolved only when needed: a network home must not slow
  down a run that never asks.

## Open Points

- A custom `UserKnownHostsFile` in `~/.ssh/config` is not followed;
  `setupHint` can name it as the cause when ssh still does not know the
  host after `trust`.
- Published fingerprints are known for GitHub and Azure DevOps only.
