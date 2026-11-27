<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# SSH-Host-Keys von Git-Remotes

## Motivation

- Auf einem neuen Rechner scheitert der erste git-Befehl gegen ein
  ssh-Remote: ssh kennt den Host noch nicht und bricht mit »Host key
  verification failed« ab.
- Dieselben Worte erscheinen auch, wenn ein bekannter Host plötzlich einen
  anderen Key zeigt – ein Key-Wechsel oder ein Angriff. Nur der erste Fall
  darf durch Vertrauen in den Key behoben werden.
- Werkzeuge auf Basis von gg_git müssen diese Fälle unterscheiden, den Key
  eines Hosts anzeigen und ihn speichern, sobald der Nutzer ihm vertraut –
  ohne zu raten, welches ssh und welche known_hosts-Datei git verwendet.

## Strategie

- Eine Klasse, `SshHostKeys`, neben `GitRetry`: Beide betreffen den
  Transport von git, nicht ein Repository.
- Die stderr-Ausgabe von git einordnen, statt ssh getrennt aufzurufen.
- Den Host-Key mit git selbst lesen, damit das ssh und die ssh-Config
  eines echten Clones verwendet werden.
- Fingerprints in Dart berechnen und mit denen vergleichen, die GitHub und
  Azure DevOps veröffentlichen.
- In die known_hosts-Datei des Nutzers nur in `trust` schreiben.

## Den Fehler einordnen

- `isUnknownHost`: »Host key verification failed« ohne geänderten Key.
- `isChangedHostKey`: »REMOTE HOST IDENTIFICATION HAS CHANGED«.
- `isKeyRejected`: »Permission denied (publickey)«.
- `setupHint` macht aus jedem Fall den nächsten Schritt: `git ls-remote
  <url>` bei einem unbekannten Host, `ssh-keygen -R <host>` bei einem
  geänderten Key und bei einem abgelehnten Key den Key-Typ und die
  Einstellungsseite des Hosts (Azure DevOps nimmt nur RSA-Keys).
- `hostOf` liest den Host so, wie known_hosts ihn nennt: `host`, oder
  `[host]:port` bei einem anderen Port als 22.

## Den Key lesen

- `scan` führt `git ls-remote <url> HEAD` mit einem `GIT_SSH_COMMAND` aus,
  das den Key in eine eigene, leere known_hosts-Datei übernimmt.
- Das Kommando baut auf dem ssh-Kommando des Nutzers auf –
  `GIT_SSH_COMMAND`, `core.sshCommand`, sonst `ssh` –, damit Proxys und
  ssh-Configs weiter greifen. Git for Windows bringt ein eigenes ssh mit;
  `ssh-keyscan` liegt dort oft nicht im PATH.
- Der Temp-Pfad wird doppelt gequotet: doppelte Anführungszeichen für ssh,
  das den Wert an Leerzeichen trennt, einfache für sh.
- `SshHostKey.fingerprint` ist der SHA256 des Keys, wie `ssh-keygen -l` ihn
  ausgibt; `checkFingerprint` antwortet `matches`, `differs` oder `unknown`.

## Den Key speichern

- `trust` hängt an `~/.ssh/known_hosts` an und überspringt Zeilen, die
  schon drinstehen.
- Der Home-Ordner wird gefunden wie bei Git for Windows: HOME, sonst
  HOMEDRIVE + HOMEPATH, wenn der Ordner existiert, sonst USERPROFILE.
- Der Pfad wird erst bei Bedarf ermittelt: Ein Netzwerk-Home darf einen
  Lauf, der nie fragt, nicht bremsen.

## Offene Punkte

- Eine eigene `UserKnownHostsFile` in `~/.ssh/config` wird nicht
  berücksichtigt; `setupHint` nennt sie als Ursache, wenn ssh den Host
  nach `trust` immer noch nicht kennt.
- Veröffentlichte Fingerprints sind nur für GitHub und Azure DevOps
  hinterlegt.
