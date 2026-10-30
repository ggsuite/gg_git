<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# ssh-Probleme erklären, wenn git fetch scheitert

## Motivation

- `SshHostKeys.setupHint` sagt bereits, was zu tun ist, wenn ssh für einen
  Host nicht eingerichtet ist: ein unbekannter Host, ein geänderter
  Host-Key oder ein abgelehnter Nutzer-Key.
- `Fetch` meldete einen solchen Fehler trotzdem als rohen git-Fehler. Jedes
  Werkzeug, das fetcht, musste die Erklärung selbst ergänzen – oder ließ
  den Entwickler mit »Host key verification failed« allein.

## Strategie

- Das Problem dort erklären, wo der Fetch scheitert, in `Fetch` selbst,
  damit jeder Aufrufer es ohne eigenen Code bekommt.
- Die URL von `origin` nur abfragen, wenn der Fehler ein ssh-Problem ist:
  Ein normaler Fehler kostet keinen zusätzlichen git-Aufruf.

## Realisierung

- `SshHostKeys.isSetupProblem` beantwortet, ob stderr einen der Fälle
  zeigt, die `setupHint` erklärt.
- `Fetch.get` hängt dann `setupHint` an seine Exception an, mit der URL von
  `origin` aus `git remote get-url origin`.
- Jeder andere Fehler wird gemeldet wie bisher.

## Offene Punkte

- `Fetch` holt vom Remote, das git wählt; der Hinweis nennt immer `origin`.
