<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Explain ssh problems when git fetch fails

## Motivation

- `SshHostKeys.setupHint` already tells what to do when ssh is not set up
  for a host: an unknown host, a changed host key or a refused user key.
- `Fetch` still reported such a failure as a bare git error. Every tool
  that fetches had to add the explanation on its own – or left the
  developer with »Host key verification failed«.

## Strategy

- Explain the problem where the fetch fails, in `Fetch` itself, so every
  caller gets it without code of its own.
- Ask for the url of `origin` only when the error is an ssh problem: a
  normal failure costs no extra git call.

## Implementation

- `SshHostKeys.isSetupProblem` answers whether stderr shows one of the
  cases `setupHint` explains.
- `Fetch.get` appends `setupHint` to its exception when it does, with the
  url of `origin` from `git remote get-url origin`.
- Every other failure is reported as before.

## Open Points

- `Fetch` fetches the remote git chooses; the hint always names `origin`.
