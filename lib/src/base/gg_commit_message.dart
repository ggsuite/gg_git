// @license
// Copyright (c) 2019 - 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// Every commit message gg generates itself starts with this prefix.
///
/// The prefix is a contract, not decoration: a commit carrying it contains
/// gg's own bookkeeping and nothing of the user's work. Producers keep that
/// promise by committing with a pathspec; readers rely on it to tell
/// generated commits from manual ones.
const String ggCommitPrefix = '#gg: ';

/// The message prefix of the merge that folds the released default branch
/// back into the feature branch after a publish.
///
/// It marks the point up to which everything on the feature branch is
/// released — a squash merge never makes the feature commits ancestors of the
/// default branch, so this commit is the only anchor for »what was already
/// published«. Producer and reader share the constant so the two cannot drift.
const String ggMergeBackPrefix = '${ggCommitPrefix}merge the published ';

/// Commit subjects gg versions before [ggCommitPrefix] created on a feature
/// branch.
///
/// They are still treated as generated so tickets started with an older gg
/// keep being recognized correctly. Everything else counts as a manual
/// change — an unclassifiable commit must never be mistaken for bookkeeping.
const Set<String> legacyGgCommitMessages = {
  'gg_multi: changed references to path',
  'gg_multi: changed references to git',
  'gg_multi: changed references to local',
  'Gg Multi: changed references to pub.dev',
};

/// Whether [subject] is a commit message gg generated itself.
///
/// True when it carries [ggCommitPrefix], or is one of the exact
/// [legacyGgCommitMessages] older gg versions wrote.
bool isGgGenerated(String subject) {
  final trimmed = subject.trim();
  return trimmed.startsWith(ggCommitPrefix) ||
      legacyGgCommitMessages.contains(trimmed);
}
